"""Run the production release script with fake tools through macOS's /bin/bash.

The Python stub records discovery rather than starting another unittest process,
so these integration checks never invoke Xcode or recursively discover themselves.
"""
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest


class ValidateReleaseIntegrationTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory(prefix="movingsoon validation regression ")
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.repo = self.root / "fixture repo"
        scripts = self.repo / "scripts"
        scripts.mkdir(parents=True)
        self.script = scripts / "validate_release.sh"
        shutil.copyfile(Path(__file__).with_name("validate_release.sh"), self.script)
        self.build = self.repo / "build outputs"
        self.log = self.root / "tool calls.jsonl"
        self.app = self.build / "DerivedData/Build/Products/Release-iphonesimulator/movingsoon.app.app"

        helper = self.root / "stub tools.py"
        helper.write_text('''import json
import os
from pathlib import Path
import sys

tool, args = sys.argv[1], sys.argv[2:]
with Path(os.environ["MOVINGSOON_TEST_LOG"]).open("a") as output:
    output.write(json.dumps({"tool": tool, "args": args}) + "\\n")
if tool == "python3":
    if args == ["scripts/select_simulator.py"]:
        print("QA-TEST-SIMULATOR")
    elif args == ["-m", "unittest", "discover", "-s", "scripts", "-p", "test_*.py"]:
        pass  # Never start recursive test discovery.
    elif args and args[0] in ("scripts/check_release_bundle.py", "scripts/check_catalog_links.py"):
        pass
    else:
        raise SystemExit("Unexpected Python command in integration fixture")
elif tool == "xcodebuild" and args and args[0] in ("-version", "build", "test"):
    print("Stub Xcode invocation accepted")
else:
    raise SystemExit("Unexpected tool in integration fixture")
''')
        binary_dir = self.root / "fake tools"
        binary_dir.mkdir()
        for tool in ("python3", "xcodebuild"):
            executable = binary_dir / tool
            executable.write_text(
                '#!/bin/bash\nexec "$MOVINGSOON_TEST_PYTHON" "$MOVINGSOON_TEST_STUB" '
                + tool + ' "$@"\n'
            )
            executable.chmod(0o755)

        self.environment = os.environ.copy()
        for key in ("MOVINGSOON_SIMULATOR_UDID", "CENSUS_API_KEY", "BASH_ENV", "ENV"):
            self.environment.pop(key, None)
        self.environment.update({
            "PATH": str(binary_dir) + os.pathsep + "/usr/bin:/bin",
            "MOVINGSOON_BUILD_DIR": str(self.build),
            "MOVINGSOON_TEST_PYTHON": sys.executable,
            "MOVINGSOON_TEST_STUB": str(helper),
            "MOVINGSOON_TEST_LOG": str(self.log),
        })

    def run_script(self, *arguments):
        result = subprocess.run(
            ["/bin/bash", str(self.script), *arguments],
            cwd=self.root, env=self.environment, capture_output=True, text=True, timeout=20,
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        return [json.loads(line) for line in self.log.read_text().splitlines()]

    def calls(self, records, tool):
        return [record["args"] for record in records if record["tool"] == tool]

    def assert_optional_bundle_check(self, records):
        checks = [args for args in self.calls(records, "python3")
                  if args and args[0] == "scripts/check_release_bundle.py"]
        self.assertEqual(checks, [["scripts/check_release_bundle.py", "--app-bundle", str(self.app)]])
        # Spaces in both the checkout and build directory must survive shell expansion.
        build = next(args for args in self.calls(records, "xcodebuild") if args[0] == "build")
        self.assertEqual(build[build.index("-derivedDataPath") + 1], str(self.build / "DerivedData"))

    def test_optional_key_release_build_without_tests_works_in_system_bash(self):
        records = self.run_script("--skip-tests")
        self.assert_optional_bundle_check(records)
        self.assertIn(["scripts/check_catalog_links.py"], self.calls(records, "python3"))
        self.assertFalse(any(args[0] == "test" for args in self.calls(records, "xcodebuild")))
        self.assertNotIn(["scripts/select_simulator.py"], self.calls(records, "python3"))

    def test_required_key_provisions_and_checks_the_built_bundle(self):
        self.environment["CENSUS_API_KEY"] = "fixture-only-not-a-real-key"
        records = self.run_script("--require-census-key", "--skip-tests")
        checks = [args for args in self.calls(records, "python3")
                  if args and args[0] == "scripts/check_release_bundle.py"]
        self.assertEqual(checks, [
            ["scripts/check_release_bundle.py", "--provision-census-key", "--require-census-key"],
            ["scripts/check_release_bundle.py", "--app-bundle", str(self.app), "--require-census-key"],
        ])

    def test_default_validation_selects_a_simulator_and_runs_tests_without_a_key(self):
        records = self.run_script()
        self.assert_optional_bundle_check(records)
        self.assertIn(["scripts/select_simulator.py"], self.calls(records, "python3"))
        tests = [args for args in self.calls(records, "xcodebuild") if args[0] == "test"]
        self.assertEqual(len(tests), 1)
        self.assertEqual(tests[0][tests[0].index("-destination") + 1],
                         "platform=iOS Simulator,id=QA-TEST-SIMULATOR")
        self.assertEqual(tests[0][tests[0].index("-derivedDataPath") + 1], str(self.build / "DerivedData"))
        result_bundle = tests[0][tests[0].index("-resultBundlePath") + 1]
        self.assertEqual(Path(result_bundle).parent, self.build)
        self.assertTrue(result_bundle.endswith(".xcresult"))
        self.assertIn("CODE_SIGNING_ALLOWED=NO", tests[0])


if __name__ == "__main__":
    unittest.main()
