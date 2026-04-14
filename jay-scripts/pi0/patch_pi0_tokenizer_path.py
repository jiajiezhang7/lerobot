#!/usr/bin/env python3
import argparse
import json
from pathlib import Path


def patch_preprocessor(policy_dir: Path, tokenizer_dir: Path) -> int:
    preprocessor_path = policy_dir / "policy_preprocessor.json"
    if not preprocessor_path.exists():
        raise FileNotFoundError(f"Missing {preprocessor_path}")

    data = json.loads(preprocessor_path.read_text())
    patched = False
    for step in data.get("steps", []):
        if step.get("registry_name") != "tokenizer_processor":
            continue
        config = step.setdefault("config", {})
        if config.get("tokenizer_name") != str(tokenizer_dir):
            config["tokenizer_name"] = str(tokenizer_dir)
            patched = True

    if patched:
        preprocessor_path.write_text(json.dumps(data, indent=2) + "\n")

    return 0


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--policy-dir", required=True, type=Path)
    parser.add_argument("--tokenizer-dir", required=True, type=Path)
    args = parser.parse_args()

    required = [
        args.tokenizer_dir / "tokenizer.model",
        args.tokenizer_dir / "tokenizer_config.json",
    ]
    missing = [str(path) for path in required if not path.exists()]
    if missing:
        raise FileNotFoundError(f"Tokenizer directory is incomplete: {missing}")

    return patch_preprocessor(args.policy_dir, args.tokenizer_dir)


if __name__ == "__main__":
    raise SystemExit(main())

