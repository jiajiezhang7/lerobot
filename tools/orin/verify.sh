#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd -- "${SCRIPT_DIR}/../.." && pwd)
DEFAULT_CONFIG="${REPO_ROOT}/configs/orin/so101.yaml"

DRY_RUN=0
CONFIG_PATH="${DEFAULT_CONFIG}"
OUTPUT_PATH="${OUTPUT_PATH:-${REPO_ROOT}/env-report.json}"
CONDA_ENV_NAME="${CONDA_ENV_NAME:-lerobot-jp61}"
MINIFORGE_DIR="${MINIFORGE_DIR:-${HOME}/miniforge3}"
ENV_PREFIX="${MINIFORGE_DIR}/envs/${CONDA_ENV_NAME}"

log() {
  printf '[orin-verify] %s\n' "$*"
}

usage() {
  cat <<EOF
Usage: $(basename "$0") [options]

Options:
  --config PATH         Path to SO101 YAML config. Default: ${DEFAULT_CONFIG}
  --output PATH         Path to write env-report.json. Default: ${OUTPUT_PATH}
  --dry-run             Print planned checks without generating the report.
  --help                Show this help.
EOF
}

parse_args() {
  while (($#)); do
    case "$1" in
      --config)
        CONFIG_PATH="$2"
        shift 2
        ;;
      --output)
        OUTPUT_PATH="$2"
        shift 2
        ;;
      --dry-run)
        DRY_RUN=1
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

main() {
  parse_args "$@"
  [[ -f "${CONFIG_PATH}" ]] || {
    printf 'Config not found: %s\n' "${CONFIG_PATH}" >&2
    exit 1
  }

  if ((DRY_RUN)); then
    log "DRY-RUN: collect host facts, direct env binary probes, and write ${OUTPUT_PATH}"
    exit 0
  fi

  OUTPUT_PATH="${OUTPUT_PATH}" CONFIG_PATH="${CONFIG_PATH}" CONDA_ENV_NAME="${CONDA_ENV_NAME}" \
  MINIFORGE_DIR="${MINIFORGE_DIR}" ENV_PREFIX="${ENV_PREFIX}" python3 - <<'PY'
import glob
import json
import os
import platform
import shutil
import subprocess
from pathlib import Path


output_path = Path(os.environ["OUTPUT_PATH"])
config_path = Path(os.environ["CONFIG_PATH"])
conda_env_name = os.environ["CONDA_ENV_NAME"]
miniforge_dir = Path(os.environ["MINIFORGE_DIR"])
env_prefix = Path(os.environ["ENV_PREFIX"])
conda = miniforge_dir / "bin" / "conda"
env_bin = env_prefix / "bin"
env_lib = env_prefix / "lib"


def run(command, stdin_text=None):
    env = os.environ.copy()
    env["PATH"] = f"{env_bin}:{env.get('PATH', '')}"
    env["LD_LIBRARY_PATH"] = f"{env_lib}:{env.get('LD_LIBRARY_PATH', '')}" if env.get("LD_LIBRARY_PATH") else str(env_lib)
    completed = subprocess.run(command, input=stdin_text, capture_output=True, text=True, env=env)
    return {
        "command": command,
        "returncode": completed.returncode,
        "stdout": completed.stdout.strip(),
        "stderr": completed.stderr.strip(),
    }


def command_available(name):
    return shutil.which(name) is not None


report = {
    "config_path": str(config_path),
    "system": {
        "uname": platform.uname()._asdict(),
        "os_release": Path("/etc/os-release").read_text(encoding="utf-8").splitlines() if Path("/etc/os-release").exists() else [],
        "nv_tegra_release": Path("/etc/nv_tegra_release").read_text(encoding="utf-8").splitlines() if Path("/etc/nv_tegra_release").exists() else [],
        "nvidia_l4t_core": run(["dpkg-query", "-W", "-f=${Version}", "nvidia-l4t-core"]),
        "python3": run(["python3", "--version"]),
        "nvcc": run(["nvcc", "--version"]) if command_available("nvcc") else {"returncode": 127, "stdout": "", "stderr": "nvcc not found"},
    },
    "resources": {
        "disk": run(["df", "-h", "/", str(Path.home())]),
        "memory": run(["free", "-h"]),
        "groups": run(["id"]),
    },
    "devices": {
        "tty": sorted(glob.glob("/dev/ttyACM*") + glob.glob("/dev/ttyUSB*")),
        "video": sorted(glob.glob("/dev/video*")),
        "usb": run(["lsusb"]) if command_available("lsusb") else {"returncode": 127, "stdout": "", "stderr": "lsusb not found"},
    },
    "camera_checks": {
        "v4l2_ctl": run(["v4l2-ctl", "--list-devices"]) if command_available("v4l2-ctl") else {"returncode": 127, "stdout": "", "stderr": "v4l2-ctl not found"},
    },
    "conda": {
        "present": conda.exists(),
        "path": str(conda),
        "env_name": conda_env_name,
        "env_list": run([str(conda), "env", "list"]) if conda.exists() else {"returncode": 127, "stdout": "", "stderr": "conda not found"},
    },
}

report["runtime"] = {
    "python": run([str(env_bin / "python"), "--version"]),
    "ffmpeg": run([str(env_bin / "ffmpeg"), "-version"]),
    "lerobot_info": run([str(env_bin / "lerobot-info")]),
    "torch_probe": run(
        [
            str(env_bin / "python"),
            "-c",
            (
                "import json, torch, torchvision, av, serial; "
                "print(json.dumps({"
                "'torch': torch.__version__, "
                "'torchvision': torchvision.__version__, "
                "'cuda_available': torch.cuda.is_available()"
                "}))"
            ),
        ]
    ),
    "find_cameras_help": run([str(env_bin / "lerobot-find-cameras"), "--help"]),
    "setup_motors_help": run([str(env_bin / "lerobot-setup-motors"), "--help"]),
    "record_help": run([str(env_bin / "lerobot-record"), "--help"]),
    "teleoperate_help": run([str(env_bin / "lerobot-teleoperate"), "--help"]),
    "find_port_probe": run([str(env_bin / "lerobot-find-port")], stdin_text="\n\n"),
}

report["smoke_tests"] = {
    "serial_devices_present": bool(report["devices"]["tty"]),
    "video_devices_present": bool(report["devices"]["video"]),
    "so101_bringup": "manual action required",
    "camera_detection": "ready for manual validation" if report["devices"]["video"] else "skipped: no video devices detected",
    "find_port_without_motor": report["runtime"]["find_port_probe"]["stderr"] or report["runtime"]["find_port_probe"]["stdout"],
}

output_path.write_text(json.dumps(report, indent=2, sort_keys=True), encoding="utf-8")
print(str(output_path))
PY

  log "Wrote report to ${OUTPUT_PATH}"
}

main "$@"
