#!/usr/bin/env python3
import argparse
import json
from pathlib import Path


def patch_config(policy_dir: Path, vlm_dir: Path) -> None:
    config_path = policy_dir / "config.json"
    if not config_path.exists():
        raise FileNotFoundError(f"Missing config.json: {config_path}")

    config = json.loads(config_path.read_text())
    config["vlm_model_name"] = str(vlm_dir)
    config_path.write_text(json.dumps(config, indent=4) + "\n")


def patch_preprocessor(policy_dir: Path, vlm_dir: Path) -> None:
    preprocessor_path = policy_dir / "policy_preprocessor.json"
    if not preprocessor_path.exists():
        raise FileNotFoundError(f"Missing policy_preprocessor.json: {preprocessor_path}")

    preprocessor = json.loads(preprocessor_path.read_text())
    patched = False
    for step in preprocessor.get("steps", []):
        if step.get("registry_name") == "tokenizer_processor":
            step.setdefault("config", {})["tokenizer_name"] = str(vlm_dir)
            patched = True

    if not patched:
        raise ValueError(f"No tokenizer_processor found in {preprocessor_path}")

    preprocessor_path.write_text(json.dumps(preprocessor, indent=2) + "\n")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--policy-dir", required=True, type=Path)
    parser.add_argument("--vlm-dir", required=True, type=Path)
    args = parser.parse_args()

    policy_dir = args.policy_dir.resolve()
    vlm_dir = args.vlm_dir.resolve()

    patch_config(policy_dir, vlm_dir)
    patch_preprocessor(policy_dir, vlm_dir)

    print(f"Patched SmolVLA config and preprocessor in {policy_dir}")
    print(f"Local VLM path: {vlm_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
