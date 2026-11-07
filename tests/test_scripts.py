import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]


class ScriptTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        shutil.copytree(ROOT / "scripts", self.root / "scripts")
        (self.root / "bin").mkdir()
        self.env = {
            **os.environ,
            "PATH": f"{self.root / 'bin'}:{os.environ['PATH']}",
            "LAB_LANG": "en",
            "MOCK_CALLS": str(self.root / "calls"),
        }
        self.env.pop("SUBSCRIPTION_ID", None)
        self.env.pop("RG", None)
        self.env.pop("RESOURCE_GROUP", None)
        (self.root / ".lab.env").write_text(
            'export RG="rg-test"\n'
            'export VMSS="vmss-test"\n'
            'export LB_IP="127.0.0.1"\n'
            'export WORKSPACE="law-test"\n'
            'export SUBSCRIPTION_ID="subscription-test"\n'
            'export LAB_LANG="en"\n'
        )
        self.mock(
            "az",
            """
printf '%s\\n' "$*" >> "$MOCK_CALLS"
case "$1 $2" in
  'account show') echo "${MOCK_SUBSCRIPTION:-subscription-test}" ;;
  'vmss list-instances') printf '0\\n1\\n' ;;
  'vmss run-command')
    if [[ "${MOCK_FAILURE:-}" == cli && "$*" == *'--instance-id 1 '* ]]; then exit 17; fi
    if [[ "${MOCK_FAILURE:-}" == remote && "$*" == *'--instance-id 1 '* ]]; then
      printf 'Enable succeeded: [stdout] [stderr] stress: command not found\\n'
    else
      printf 'Enable succeeded: [stdout] LAB_STRESS_OK [stderr]\\n'
    fi
    ;;
  'group exists')
    if [[ "${MOCK_FAILURE:-}" == exists ]]; then exit 19; fi
    echo "${MOCK_GROUP_EXISTS:-true}"
    ;;
  'monitor log-analytics')
    if [[ "$*" == *'workspace list'* ]]; then echo law-test; fi
    if [[ "$*" == *'workspace delete'* && "${MOCK_FAILURE:-}" == workspace ]]; then
      exit 20
    fi
    ;;
  'deployment group')
    if [[ "$*" == *'group show'* ]]; then echo test-output; fi
    ;;
  'rest --url')
    if [[ "$*" == *'--method delete'* ]]; then
      if [[ "${MOCK_FAILURE:-}" == budget-delete ]]; then exit 21; fi
    else
      if [[ "${MOCK_FAILURE:-}" == budget-list ]]; then exit 22; fi
      printf '%s/budget-halab\\n' "${3%%\\?*}"
    fi
    ;;
esac
""",
        )
        self.mock("sleep", "exit 0")

    def mock(self, name, body):
        path = self.root / "bin" / name
        path.write_text("#!/usr/bin/env bash\nset -eu\n" + body + "\n")
        path.chmod(0o755)

    def run_script(self, name, *args, **env):
        return subprocess.run(
            ["bash", str(self.root / "scripts" / name), *args],
            cwd=self.root,
            env={**self.env, **env},
            text=True,
            capture_output=True,
            timeout=20,
        )

    def calls(self):
        path = self.root / "calls"
        return path.read_text() if path.exists() else ""

    def test_stress_reports_cli_failure(self):
        result = self.run_script("stress.sh", "start", "900", MOCK_FAILURE="cli")
        self.assertNotEqual(result.returncode, 0, result.stdout)
        self.assertNotIn("Load started.", result.stdout)
        self.assertEqual(self.calls().count("vmss run-command invoke"), 2)

    def test_stress_reports_remote_failure(self):
        result = self.run_script("stress.sh", "start", "900", MOCK_FAILURE="remote")
        self.assertNotEqual(result.returncode, 0, result.stdout)
        self.assertIn("command not found", result.stderr)
        self.assertEqual(self.calls().count("vmss run-command invoke"), 2)

    def test_stress_validates_duration_before_azure_calls(self):
        result = self.run_script("stress.sh", "start", "invalid")
        self.assertNotEqual(result.returncode, 0, result.stdout)
        self.assertEqual(self.calls(), "")

    def test_stress_success_waits_for_both_instances(self):
        result = self.run_script("stress.sh", "start", "900")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.calls().count("vmss run-command invoke"), 2)
        self.assertIn("Load started.", result.stdout)

    def test_subscription_mismatch_blocks_cleanup(self):
        result = self.run_script(
            "cleanup.sh", "-y", "--wait", MOCK_SUBSCRIPTION="other-subscription"
        )
        self.assertNotEqual(result.returncode, 0, result.stdout)
        self.assertNotIn("group delete", self.calls())
        self.assertTrue((self.root / ".lab.env").exists())

    def test_cleanup_requires_explicit_target_without_env(self):
        (self.root / ".lab.env").unlink()
        result = self.run_script("cleanup.sh", "-y")
        self.assertNotEqual(result.returncode, 0, result.stdout)
        self.assertNotIn("group delete", self.calls())

    def test_cleanup_preserves_state_when_existence_check_fails(self):
        result = self.run_script("cleanup.sh", "-y", MOCK_FAILURE="exists")
        self.assertNotEqual(result.returncode, 0, result.stdout)
        self.assertTrue((self.root / ".lab.env").exists())
        self.assertNotIn("group delete", self.calls())

    def test_cleanup_reports_workspace_deletion_failure(self):
        result = self.run_script("cleanup.sh", "-y", MOCK_FAILURE="workspace")
        self.assertNotEqual(result.returncode, 0, result.stdout)
        self.assertTrue((self.root / ".lab.env").exists())

    def test_cleanup_removes_budget_after_group_was_deleted(self):
        result = self.run_script(
            "cleanup.sh", "-y", "--wait", MOCK_GROUP_EXISTS="false"
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("budgets/budget-halab?api-version=2024-08-01", self.calls())
        self.assertIn("--method delete", self.calls())
        self.assertNotIn("group delete", self.calls())

    def test_cleanup_preserves_state_when_budget_listing_fails(self):
        result = self.run_script("cleanup.sh", "-y", MOCK_FAILURE="budget-list")
        self.assertNotEqual(result.returncode, 0, result.stdout)
        self.assertTrue((self.root / ".lab.env").exists())
        self.assertNotIn("group delete", self.calls())

    def test_cleanup_preserves_state_when_budget_deletion_fails(self):
        result = self.run_script("cleanup.sh", "-y", MOCK_FAILURE="budget-delete")
        self.assertNotEqual(result.returncode, 0, result.stdout)
        self.assertTrue((self.root / ".lab.env").exists())
        self.assertNotIn("group delete", self.calls())

    def test_cleanup_accepts_explicit_group_without_env(self):
        (self.root / ".lab.env").unlink()
        result = self.run_script(
            "cleanup.sh", "-y", "--wait", RESOURCE_GROUP="rg-explicit"
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("group delete -n rg-explicit --yes", self.calls())

    def test_deploy_records_subscription_when_ready(self):
        (self.root / ".lab-key").touch()
        (self.root / ".lab-key.pub").write_text("test-public-key")
        self.mock("curl", "exit 0")
        result = self.run_script("deploy.sh")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("Ready!", result.stdout)
        self.assertIn(
            'export SUBSCRIPTION_ID="subscription-test"',
            (self.root / ".lab.env").read_text(),
        )

    def test_deploy_fails_when_web_servers_never_become_ready(self):
        (self.root / ".lab-key").touch()
        (self.root / ".lab-key.pub").write_text("test-public-key")
        self.mock("curl", "exit 22")
        result = self.run_script("deploy.sh")
        self.assertNotEqual(result.returncode, 0, result.stdout)
        self.assertNotIn("Web URL:", result.stdout)
        self.assertTrue((self.root / ".lab.env").exists())

    def test_http_errors_are_counted_as_failures(self):
        self.mock(
            "curl",
            """
if [[ "$*" == *'-f'* ]]; then exit 22; fi
printf 'Service Unavailable\\n'
""",
        )
        result = self.run_script("curl-loop.sh", "2")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("2 FAILED", result.stdout)
        self.assertNotIn("Service Unavailable", result.stdout)


if __name__ == "__main__":
    unittest.main()
