#!/usr/bin/env python3
import argparse
import json
import sys
from pathlib import Path

ROOT_DIR = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT_DIR / ".vendor" / "pi0_fast_pydeps"))


def check_path(path: Path, label: str) -> bool:
    ok = path.exists()
    status = "OK" if ok else "MISSING"
    print(f"[{status}] {label}: {path}")
    return ok


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--device", default="cpu")
    args = parser.parse_args()

    import_ok = True
    for module_name in ("sentencepiece", "transformers", "peft", "scipy"):
        try:
            __import__(module_name)
            print(f"[OK] {module_name} import")
        except Exception as exc:  # pragma: no cover - user-facing
            import_ok = False
            print(f"[MISSING] {module_name} import: {exc}")

    try:
        from transformers import AutoProcessor, AutoTokenizer
    except Exception as exc:  # pragma: no cover - user-facing
        print(f"[FAIL] transformers tokenizer imports: {exc}")
        return 1

    model_dir = ROOT_DIR / "models" / "lerobot_pi0_fast_base"
    text_tokenizer_dir = ROOT_DIR / "models" / "google_paligemma_3b_pt_224_tokenizer"
    action_tokenizer_dir = ROOT_DIR / "models" / "lerobot_fast_action_tokenizer"
    dataset_info_path = (
        Path.home() / ".cache" / "huggingface" / "lerobot" / "grabfruit" / "test" / "meta" / "info.json"
    )

    check_path(model_dir, "pi0-fast model dir")
    check_path(model_dir / "model.safetensors", "pi0-fast weights")
    check_path(model_dir / "config.json", "pi0-fast config")
    check_path(model_dir / "policy_preprocessor.json", "pi0-fast preprocessor")
    text_tokenizer_ok = check_path(text_tokenizer_dir / "tokenizer.model", "paligemma tokenizer.model")
    text_tokenizer_ok &= check_path(
        text_tokenizer_dir / "tokenizer_config.json", "paligemma tokenizer_config.json"
    )
    action_tokenizer_ok = check_path(
        action_tokenizer_dir / "tokenizer_config.json", "fast action tokenizer_config.json"
    )
    dataset_ok = check_path(dataset_info_path, "grabfruit dataset info")

    if dataset_ok:
        info = json.loads(dataset_info_path.read_text())
        print(
            f"[INFO] dataset episodes={info['total_episodes']} "
            f"frames={info['total_frames']} fps={info['fps']} "
            f"robot_type={info['robot_type']}"
        )
        print("[INFO] dataset image keys: observation.images.front, observation.images.side")

    try:
        import lerobot.policies.pi0_fast.configuration_pi0_fast  # noqa: F401
        from lerobot.configs.policies import PreTrainedConfig

        cfg = PreTrainedConfig.from_pretrained(model_dir)
        cfg.device = args.device
        print(f"[OK] PreTrainedConfig.from_pretrained(local pi0-fast): type={cfg.type}")
        print(f"[INFO] text_tokenizer_name={cfg.text_tokenizer_name}")
        print(f"[INFO] action_tokenizer_name={cfg.action_tokenizer_name}")
    except Exception as exc:  # pragma: no cover - user-facing
        print(f"[FAIL] PreTrainedConfig.from_pretrained(local pi0-fast): {exc}")
        return 1

    if text_tokenizer_ok:
        try:
            AutoTokenizer.from_pretrained(str(text_tokenizer_dir))
            print("[OK] AutoTokenizer.from_pretrained(local paligemma tokenizer dir)")
        except Exception as exc:  # pragma: no cover - user-facing
            print(f"[FAIL] AutoTokenizer.from_pretrained(local paligemma tokenizer dir): {exc}")
            return 1

    if action_tokenizer_ok:
        try:
            AutoProcessor.from_pretrained(str(action_tokenizer_dir), trust_remote_code=True)
            print("[OK] AutoProcessor.from_pretrained(local FAST tokenizer dir)")
        except Exception as exc:  # pragma: no cover - user-facing
            print(f"[FAIL] AutoProcessor.from_pretrained(local FAST tokenizer dir): {exc}")
            return 1

    try:
        from lerobot.policies.pi0_fast.modeling_pi0_fast import PI0FastPolicy

        policy = PI0FastPolicy.from_pretrained(model_dir, config=cfg, local_files_only=True)
        print(f"[OK] PI0FastPolicy.from_pretrained(local, device={args.device})")
        del policy
    except Exception as exc:  # pragma: no cover - user-facing
        print(f"[FAIL] PI0FastPolicy.from_pretrained(local_files_only=True): {exc}")
        return 1

    if not import_ok:
        return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
