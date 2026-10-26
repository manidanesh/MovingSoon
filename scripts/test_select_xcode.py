"""Regression checks for numeric Xcode ordering and incomplete runner images."""
import plistlib
from pathlib import Path
import tempfile
import unittest

from select_xcode import parse_version, select_xcode


class SelectXcodeTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.applications = Path(self.temporary.name)

    def app(self, name, version, complete=True):
        app = self.applications / name
        (app / "Contents").mkdir(parents=True)
        with (app / "Contents/Info.plist").open("wb") as destination:
            plistlib.dump({"CFBundleShortVersionString": version}, destination)
        if complete:
            tool = app / "Contents/Developer/usr/bin/xcodebuild"
            tool.parent.mkdir(parents=True)
            tool.touch()
        return app / "Contents/Developer"

    def test_numeric_versions_choose_newest_compatible_installation(self):
        self.app("Xcode_25.app", "25.4")
        self.app("Xcode_26.9.app", "26.9")
        expected = self.app("Xcode_26.10.app", "26.10")
        self.app("Xcode.app", "26.0.1")
        self.assertEqual(select_xcode(self.applications), expected)

    def test_incomplete_or_invalid_newer_installations_do_not_hide_usable_xcode(self):
        expected = self.app("Xcode.app", "26.0")
        self.app("Xcode_incomplete.app", "27.0", complete=False)
        self.app("Xcode_invalid.app", "not-a-version")
        broken = self.applications / "Xcode_broken.app/Contents"
        broken.mkdir(parents=True)
        (broken / "Info.plist").write_text("invalid plist")
        self.assertEqual(select_xcode(self.applications), expected)

    def test_only_old_installations_fail_with_required_version_and_found_version(self):
        self.app("Xcode.app", "25.4")
        with self.assertRaisesRegex(ValueError, r"Xcode 26 or later.*Xcode.app: 25\.4"):
            select_xcode(self.applications)

    def test_empty_runner_fails_with_installation_instruction(self):
        with self.assertRaisesRegex(ValueError, "no Xcode\\*\\.app installations found"):
            select_xcode(self.applications)

    def test_version_normalization_and_malformed_metadata(self):
        self.assertEqual(parse_version("26"), (26, 0, 0))
        self.assertEqual(parse_version("26.0.1"), (26, 0, 1))
        for value in (None, 26, "26.beta", "26.0.1.2", "26\n"):
            with self.subTest(value=value), self.assertRaises(ValueError):
                parse_version(value)


if __name__ == "__main__":
    unittest.main()
