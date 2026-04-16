#!/usr/bin/env python3
import argparse
import json
from pathlib import Path


def patch_config(policy_dir: Path, text_tokenizer_dir: Path, action_tokenizer_dir: Path) -> None:
    config_path = policy_dir / "config.json"
    if not config_path.exists():
        raise FileNotFoundError(f"Missing config.json: {config_path}")

    config = json.loads(config_path.read_text())
    config["text_tokenizer_name"] = str(text_tokenizer_dir)
    config["action_tokenizer_name"] = str(action_tokenizer_dir)
    config_path.write_text(json.dumps(config, indent=4) + "\n")


def patch_preprocessor(policy_dir: Path, text_tokenizer_dir: Path, action_tokenizer_dir: Path) -> None:
    preprocessor_path = policy_dir / "policy_preprocessor.json"
    if not preprocessor_path.exists():
        raise FileNotFoundError(f"Missing policy_preprocessor.json: {preprocessor_path}")

    preprocessor = json.loads(preprocessor_path.read_text())
    patched_text = False
    patched_action = False

    for step in preprocessor.get("steps", []):
        registry_name = step.get("registry_name")
        config = step.setdefault("config", {})
        if registry_name == "tokenizer_processor":
            config["tokenizer_name"] = str(text_tokenizer_dir)
            patched_text = True
        elif registry_name == "action_tokenizer_processor":
            config["action_tokenizer_name"] = str(action_tokenizer_dir)
            config["paligemma_tokenizer_name"] = str(text_tokenizer_dir)
            patched_action = True

    if not patched_text:
        raise ValueError(f"No tokenizer_processor found in {preprocessor_path}")
    if not patched_action:
        raise ValueError(f"No action_tokenizer_processor found in {preprocessor_path}")

    preprocessor_path.write_text(json.dumps(preprocessor, indent=2) + "\n")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--policy-dir", required=True, type=Path)
    parser.add_argument("--text-tokenizer-dir", required=True, type=Path)
    parser.add_argument("--action-tokenizer-dir", required=True, type=Path)
    args = parser.parse_args()

    policy_dir = args.policy_dir.resolve()
    text_tokenizer_dir = args.text_tokenizer_dir.resolve()
    action_tokenizer_dir = args.action_tokenizer_dir.resolve()

    patch_config(policy_dir, text_tokenizer_dir, action_tokenizer_dir)
    patch_preprocessor(policy_dir, text_tokenizer_dir, action_tokenizer_dir)

    print(f"Patched Pi0-Fast config and preprocessor in {policy_dir}")
    print(f"Local text tokenizer path: {text_tokenizer_dir}")
    print(f"Local action tokenizer path: {action_tokenizer_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
