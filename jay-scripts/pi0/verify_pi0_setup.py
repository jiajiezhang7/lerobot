#!/usr/bin/env python3
import json
import sys
from pathlib import Path

ROOT_DIR = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT_DIR / ".vendor" / "pi0_pydeps"))


def check_path(path: Path, label: str) -> bool:
    ok = path.exists()
    status = "OK" if ok else "MISSING"
    print(f"[{status}] {label}: {path}")
    return ok


def main() -> int:
    import_ok = True
    try:
        import sentencepiece  # noqa: F401

        print("[OK] sentencepiece import")
    except Exception as exc:  # pragma: no cover - user-facing
        import_ok = False
        print(f"[MISSING] sentencepiece import: {exc}")

    try:
        from transformers import AutoTokenizer

        print("[OK] transformers import")
    except Exception as exc:  # pragma: no cover - user-facing
        print(f"[MISSING] transformers import: {exc}")
        return 1

    model_dir = ROOT_DIR / "models" / "lerobot_pi0_base"
    tokenizer_dir = ROOT_DIR / "models" / "google_paligemma_3b_pt_224_tokenizer"
    dataset_info_path = Path.home() / ".cache" / "huggingface" / "lerobot" / "grabfruit" / "test" / "meta" / "info.json"

    check_path(model_dir, "pi0 model dir")
    check_path(model_dir / "model.safetensors", "pi0 weights")
    check_path(model_dir / "config.json", "pi0 config")
    check_path(model_dir / "policy_preprocessor.json", "pi0 preprocessor")
    tokenizer_ok = check_path(tokenizer_dir / "tokenizer.model", "paligemma tokenizer.model")
    tokenizer_ok &= check_path(tokenizer_dir / "tokenizer_config.json", "paligemma tokenizer_config.json")
    tokenizer_ok &= check_path(tokenizer_dir / "special_tokens_map.json", "paligemma special_tokens_map.json")
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
        import lerobot.policies.pi0.configuration_pi0  # noqa: F401
        from lerobot.configs.policies import PreTrainedConfig

        cfg = PreTrainedConfig.from_pretrained(model_dir)
        print(f"[OK] PreTrainedConfig.from_pretrained(local pi0): type={cfg.type}")
    except Exception as exc:  # pragma: no cover - user-facing
        print(f"[FAIL] PreTrainedConfig.from_pretrained(local pi0): {exc}")
        return 1

    preprocessor_path = model_dir / "policy_preprocessor.json"
    if preprocessor_path.exists():
        preprocessor = json.loads(preprocessor_path.read_text())
        for step in preprocessor.get("steps", []):
            if step.get("registry_name") == "tokenizer_processor":
                print(f"[INFO] tokenizer_name={step['config'].get('tokenizer_name')}")

    if tokenizer_ok:
        try:
            AutoTokenizer.from_pretrained(str(tokenizer_dir))
            print("[OK] AutoTokenizer.from_pretrained(local tokenizer dir)")
        except Exception as exc:  # pragma: no cover - user-facing
            print(f"[FAIL] AutoTokenizer.from_pretrained(local tokenizer dir): {exc}")
            return 1
    else:
        print("[WARN] tokenizer is incomplete. Accept the license on Hugging Face and rerun bootstrap_pi0_assets.sh.")

    if not import_ok:
        return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
