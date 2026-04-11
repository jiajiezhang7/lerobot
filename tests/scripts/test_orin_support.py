import subprocess
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]
BOOTSTRAP = REPO_ROOT / "tools" / "orin" / "bootstrap.sh"
VERIFY = REPO_ROOT / "tools" / "orin" / "verify.sh"
CONFIG = REPO_ROOT / "configs" / "orin" / "so101.yaml"


class OrinSupportArtifactsTest(unittest.TestCase):
    def test_expected_delivery_files_exist(self) -> None:
        self.assertTrue(BOOTSTRAP.exists(), f"missing {BOOTSTRAP}")
        self.assertTrue(VERIFY.exists(), f"missing {VERIFY}")
        self.assertTrue(CONFIG.exists(), f"missing {CONFIG}")

    def test_config_contains_expected_keys(self) -> None:
        text = CONFIG.read_text(encoding="utf-8")
        expected_snippets = [
            "robot:",
            "type: so101_follower",
            "teleop:",
            "type: so101_leader",
            "robot.port",
            "teleop.port",
            "robot.id",
            "teleop.id",
            "robot.cameras",
            "fps: 30",
            "dataset:",
            "repo_id_template:",
            "policy:",
            "mode:",
            "device: cuda",
        ]
        for snippet in expected_snippets:
            self.assertIn(snippet, text, f"missing config snippet: {snippet}")

    def test_bootstrap_supports_dry_run(self) -> None:
        completed = subprocess.run(
            ["bash", str(BOOTSTRAP), "--dry-run", "--config", str(CONFIG)],
            cwd=REPO_ROOT,
            capture_output=True,
            text=True,
        )
        self.assertEqual(
            completed.returncode,
            0,
            msg=f"bootstrap dry-run failed\nstdout:\n{completed.stdout}\nstderr:\n{completed.stderr}",
        )

    def test_verify_supports_dry_run(self) -> None:
        completed = subprocess.run(
            ["bash", str(VERIFY), "--dry-run", "--config", str(CONFIG)],
            cwd=REPO_ROOT,
            capture_output=True,
            text=True,
        )
        self.assertEqual(
            completed.returncode,
            0,
            msg=f"verify dry-run failed\nstdout:\n{completed.stdout}\nstderr:\n{completed.stderr}",
        )

    def test_bootstrap_mentions_cusparselt_runtime_setup(self) -> None:
        text = BOOTSTRAP.read_text(encoding="utf-8")
        self.assertIn("cusparselt", text.lower())


if __name__ == "__main__":
    unittest.main()
