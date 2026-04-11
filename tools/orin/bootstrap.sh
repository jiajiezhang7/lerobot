#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd -- "${SCRIPT_DIR}/../.." && pwd)
DEFAULT_CONFIG="${REPO_ROOT}/configs/orin/so101.yaml"

DRY_RUN=0
RESUME=0
WITH_REALSENSE=0
CONFIG_PATH="${DEFAULT_CONFIG}"
CONDA_ENV_NAME="${CONDA_ENV_NAME:-lerobot-jp61}"
MINIFORGE_DIR="${MINIFORGE_DIR:-${HOME}/miniforge3}"
MINIFORGE_URL="${MINIFORGE_URL:-https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-aarch64.sh}"
ENV_PREFIX="${MINIFORGE_DIR}/envs/${CONDA_ENV_NAME}"

TORCH_WHEEL_URL="https://developer.download.nvidia.cn/compute/redist/jp/v61/pytorch/torch-2.5.0a0+872d972e41.nv24.08.17622132-cp310-cp310-linux_aarch64.whl"
CUSPARSELT_URL="https://developer.download.nvidia.cn/compute/cusparselt/redist/libcusparse_lt/linux-aarch64/libcusparse_lt-linux-aarch64-0.6.3.2-archive.tar.xz"
VISION_SOURCE_URL="https://github.com/pytorch/vision/archive/refs/tags/v0.20.0.tar.gz"
FEETECH_SDK_URL="https://files.pythonhosted.org/packages/5f/8e/c53d6f9a8bf3a86a635b58eeb675723f1b040f1665a0681467756c8989aa/feetech-servo-sdk-1.0.0.tar.gz"

APT_PACKAGES=(
  build-essential
  pkg-config
  cmake
  python3-dev
  git
  curl
  wget
  v4l-utils
  libavformat-dev
  libavcodec-dev
  libavdevice-dev
  libavutil-dev
  libswscale-dev
  libswresample-dev
  libavfilter-dev
  libusb-1.0-0-dev
  libgl1
  libglib2.0-0
)

log() {
  printf '[orin-bootstrap] %s\n' "$*"
}

usage() {
  cat <<EOF
Usage: $(basename "$0") [options]

Options:
  --config PATH         Path to SO101 YAML config. Default: ${DEFAULT_CONFIG}
  --dry-run             Print planned actions without mutating the system.
  --resume              Resume an interrupted setup. Existing steps are skipped.
  --with-realsense      Install optional RealSense dependency.
  --help                Show this help.
EOF
}

run_cmd() {
  if ((DRY_RUN)); then
    log "DRY-RUN: $*"
    return 0
  fi
  "$@"
}

have_cmd() {
  command -v "$1" >/dev/null 2>&1
}

conda_bin() {
  printf '%s/bin/conda' "${MINIFORGE_DIR}"
}

env_python() {
  printf '%s/bin/python' "${ENV_PREFIX}"
}

env_pip() {
  printf '%s/bin/pip' "${ENV_PREFIX}"
}

env_bin() {
  printf '%s/bin/%s' "${ENV_PREFIX}" "$1"
}

with_env_exports() {
  export PATH="${ENV_PREFIX}/bin:${PATH}"
  export LD_LIBRARY_PATH="${ENV_PREFIX}/lib${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}"
  export CUDA_HOME="/usr/local/cuda-12.6"
}

env_pip_install() {
  if ((DRY_RUN)); then
    log "DRY-RUN: $(env_pip) $*"
    return 0
  fi
  with_env_exports
  "$(env_pip)" "$@"
}

env_python_run() {
  if ((DRY_RUN)); then
    log "DRY-RUN: $(env_python) $*"
    return 0
  fi
  with_env_exports
  "$(env_python)" "$@"
}

env_cmd_run() {
  local cmd="$1"
  shift
  if ((DRY_RUN)); then
    log "DRY-RUN: $(env_bin "${cmd}") $*"
    return 0
  fi
  with_env_exports
  "$(env_bin "${cmd}")" "$@"
}

maybe_sudo_run() {
  if ((DRY_RUN)); then
    log "DRY-RUN: $*"
    return 0
  fi

  if [[ ${EUID} -eq 0 ]]; then
    "$@"
    return 0
  fi

  if have_cmd sudo && sudo -n true 2>/dev/null; then
    sudo -n "$@"
    return 0
  fi

  log "Skipping privileged command without passwordless sudo: $*"
  return 0
}

parse_args() {
  while (($#)); do
    case "$1" in
      --config)
        CONFIG_PATH="$2"
        shift 2
        ;;
      --dry-run)
        DRY_RUN=1
        shift
        ;;
      --resume)
        RESUME=1
        shift
        ;;
      --with-realsense)
        WITH_REALSENSE=1
        shift
        ;;
      --help|-h)
        usage
        exit 0
        ;;
      *)
        printf 'Unknown argument: %s\n' "$1" >&2
        usage >&2
        exit 2
        ;;
    esac
  done
}

require_local_inputs() {
  [[ -f "${CONFIG_PATH}" ]] || {
    printf 'Config not found: %s\n' "${CONFIG_PATH}" >&2
    exit 1
  }
}

check_platform() {
  local l4t_version=""
  l4t_version=$(dpkg-query -W -f='${Version}' nvidia-l4t-core 2>/dev/null || true)
  log "Detected nvidia-l4t-core=${l4t_version:-missing}"

  if [[ -z "${l4t_version}" || "${l4t_version}" != 36.4* ]]; then
    printf 'Expected JetPack 6.1 / L4T 36.4.x, got nvidia-l4t-core=%s\n' "${l4t_version:-missing}" >&2
    exit 1
  fi

  if [[ -f /etc/nv_tegra_release ]] && ! grep -q 'R36 (release), REVISION: 4\.' /etc/nv_tegra_release; then
    printf 'Expected /etc/nv_tegra_release to report R36 revision 4.x\n' >&2
    exit 1
  fi
}

install_apt_packages() {
  log "Ensuring required APT packages are present"
  maybe_sudo_run apt-get update
  maybe_sudo_run apt-get install -y --no-install-recommends "${APT_PACKAGES[@]}"
}

download_file() {
  local url="$1"
  local output="$2"

  if have_cmd wget; then
    run_cmd wget -O "${output}" "${url}"
    return 0
  fi

  if have_cmd curl; then
    run_cmd curl -L "${url}" -o "${output}"
    return 0
  fi

  printf 'Neither wget nor curl is available\n' >&2
  exit 1
}

install_miniforge() {
  if [[ -x "$(conda_bin)" ]]; then
    log "Miniforge already present at ${MINIFORGE_DIR}"
    return 0
  fi

  local installer="/tmp/Miniforge3-Linux-aarch64.sh"
  log "Installing Miniforge into ${MINIFORGE_DIR}"
  download_file "${MINIFORGE_URL}" "${installer}"
  run_cmd bash "${installer}" -b -p "${MINIFORGE_DIR}"
}

ensure_conda_env() {
  log "Ensuring conda environment ${CONDA_ENV_NAME}"

  if ((DRY_RUN)); then
    log "DRY-RUN: $(conda_bin) create -y -n ${CONDA_ENV_NAME} python=3.10 pip"
    log "DRY-RUN: $(conda_bin) install -y -n ${CONDA_ENV_NAME} -c conda-forge ffmpeg=7.1.1 av pyserial pillow 'numpy=1.26.4' 'setuptools<81' cmake ninja"
    return 0
  fi

  if ! "$(conda_bin)" env list | awk '{print $1}' | grep -qx "${CONDA_ENV_NAME}"; then
    "$(conda_bin)" create -y -n "${CONDA_ENV_NAME}" python=3.10 pip
  elif ((RESUME)); then
    log "Reusing existing environment ${CONDA_ENV_NAME}"
  fi

  "$(conda_bin)" install -y -n "${CONDA_ENV_NAME}" -c conda-forge \
    ffmpeg=7.1.1 av pyserial pillow 'numpy=1.26.4' 'setuptools<81' cmake ninja
  env_pip_install install --upgrade pip wheel
}

install_cusparselt() {
  local archive="/tmp/libcusparse_lt-linux-aarch64-0.6.3.2-archive.tar.xz"
  local extract_dir="/tmp/libcusparselt-linux-aarch64-0.6.3.2"
  local activate_dir="${ENV_PREFIX}/etc/conda/activate.d"
  local deactivate_dir="${ENV_PREFIX}/etc/conda/deactivate.d"

  if [[ -f "${ENV_PREFIX}/lib/libcusparseLt.so.0.6.3.2" ]] && ((RESUME)); then
    log "cuSPARSELt already installed in ${ENV_PREFIX}/lib"
    return 0
  fi

  log "Installing cuSPARSELt into ${ENV_PREFIX}/lib"
  download_file "${CUSPARSELT_URL}" "${archive}"

  if ((DRY_RUN)); then
    log "DRY-RUN: extract ${archive} and copy libcusparseLt.so* into ${ENV_PREFIX}/lib"
    return 0
  fi

  rm -rf "${extract_dir}"
  mkdir -p "${extract_dir}"
  tar -xf "${archive}" -C "${extract_dir}"
  cp -a "${extract_dir}/libcusparse_lt-linux-aarch64-0.6.3.2-archive/lib/libcusparseLt.so"* "${ENV_PREFIX}/lib/"

  mkdir -p "${activate_dir}" "${deactivate_dir}"
  cat > "${activate_dir}/orin-cusparselt.sh" <<'EOF'
export _ORIN_CUSPARSELT_OLD_LD_LIBRARY_PATH="${LD_LIBRARY_PATH-}"
export LD_LIBRARY_PATH="${CONDA_PREFIX}/lib${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}"
EOF

  cat > "${deactivate_dir}/orin-cusparselt.sh" <<'EOF'
if [ -n "${_ORIN_CUSPARSELT_OLD_LD_LIBRARY_PATH+x}" ]; then
  export LD_LIBRARY_PATH="${_ORIN_CUSPARSELT_OLD_LD_LIBRARY_PATH}"
  unset _ORIN_CUSPARSELT_OLD_LD_LIBRARY_PATH
else
  unset LD_LIBRARY_PATH
fi
EOF
}

install_torch_stack() {
  local wheel="/tmp/torch-2.5.0a0+872d972e41.nv24.08.17622132-cp310-cp310-linux_aarch64.whl"
  local vision_tar="/tmp/vision-v0.20.0.tar.gz"
  local vision_src="/tmp/vision-v0.20.0-src"

  log "Installing Jetson PyTorch wheel"
  download_file "${TORCH_WHEEL_URL}" "${wheel}"
  env_pip_install install --no-cache-dir --force-reinstall "${wheel}"

  log "Building torchvision 0.20.0 against Jetson torch"
  download_file "${VISION_SOURCE_URL}" "${vision_tar}"

  if ((DRY_RUN)); then
    log "DRY-RUN: build torchvision 0.20.0 from ${vision_tar}"
    return 0
  fi

  rm -rf "${vision_src}"
  mkdir -p "${vision_src}"
  tar -xf "${vision_tar}" -C "${vision_src}" --strip-components=1
  env_pip_install uninstall -y torchvision >/dev/null 2>&1 || true

  (
    with_env_exports
    export TORCH_CUDA_ARCH_LIST=8.7
    export FORCE_CUDA=1
    export MAX_JOBS=4
    export BUILD_VERSION=0.20.0
    cd "${vision_src}"
    "$(env_pip)" install --no-deps --no-build-isolation .
  )
}

install_runtime_dependencies() {
  log "Installing runtime dependencies"
  env_pip_install install --default-timeout=120 --no-cache-dir --force-reinstall \
    numpy==1.26.4 tqdm==4.67.1 packaging==25.0 deepdiff==8.6.2 jsonlines==4.0.0 \
    imageio==2.37.3 termcolor==3.3.0 gymnasium==1.2.3 toml==0.10.2 \
    typing-inspect==0.9.0 mergedeep==1.3.4 pyyaml==6.0.3 pyyaml-include==1.4.1

  env_pip_install install --default-timeout=120 --no-cache-dir --force-reinstall --no-deps \
    draccus==0.10.0 rerun-sdk==0.26.2 opencv-python-headless==4.11.0.86

  env_pip_install install --default-timeout=120 --no-cache-dir \
    accelerate==1.13.0 huggingface-hub==0.35.3 datasets==4.8.4 diffusers==0.35.2 wandb==0.24.2

  env_pip_install install --default-timeout=120 --no-cache-dir \
    grpcio==1.73.1 protobuf==6.33.6 matplotlib==3.10.3
}

install_feetech_sdk() {
  local archive="/tmp/feetech-servo-sdk-1.0.0.tar.gz"
  local src_dir="/tmp/feetech-servo-sdk-1.0.0"

  log "Installing Feetech servo SDK"
  download_file "${FEETECH_SDK_URL}" "${archive}"

  if ((DRY_RUN)); then
    log "DRY-RUN: build and install feetech-servo-sdk from ${archive}"
    return 0
  fi

  rm -rf "${src_dir}"
  tar -xzf "${archive}" -C /tmp
  (
    with_env_exports
    cd "${src_dir}"
    "$(env_pip)" install --no-deps --no-build-isolation .
  )
}

install_lerobot_runtime() {
  log "Installing LeRobot 0.4.4 runtime"
  env_pip_install install --default-timeout=120 --no-cache-dir --no-deps 'lerobot==0.4.4'
  if ((WITH_REALSENSE)); then
    env_pip_install install --default-timeout=120 --no-cache-dir 'pyrealsense2>=2.55.1.6486,<2.57.0'
  fi
}

verify_runtime_imports() {
  log "Running runtime verification"

  env_python_run - <<'PY'
import accelerate
import cv2
import lerobot
import numpy
import scservo_sdk
import torch
import torchvision
import tqdm

print("accelerate", accelerate.__version__)
print("cv2", cv2.__version__)
print("lerobot", getattr(lerobot, "__version__", "n/a"))
print("numpy", numpy.__version__)
print("scservo_sdk", scservo_sdk.__file__)
print("torch", torch.__version__)
print("torchvision", torchvision.__version__)
print("tqdm", tqdm.__version__)
print("cuda_available", torch.cuda.is_available())
PY

  env_cmd_run ffmpeg -version
  env_cmd_run lerobot-info
  env_cmd_run lerobot-find-cameras --help >/dev/null
  env_cmd_run lerobot-setup-motors --help >/dev/null
  env_cmd_run lerobot-record --help >/dev/null
  env_cmd_run lerobot-teleoperate --help >/dev/null
}

main() {
  parse_args "$@"
  require_local_inputs
  check_platform
  install_apt_packages
  install_miniforge
  ensure_conda_env
  install_cusparselt
  install_torch_stack
  install_runtime_dependencies
  install_feetech_sdk
  install_lerobot_runtime
  verify_runtime_imports
  log "Bootstrap completed"
}

main "$@"
