import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import dotctl


class SkipReasonTest(unittest.TestCase):
    def test_platform_mismatch(self):
        self.assertEqual(
            dotctl.skip_reason("rofi", "darwin", "work", "linux", "", ""),
            "platform: linux",
        )

    def test_platform_list_match(self):
        self.assertIsNone(
            dotctl.skip_reason("x", "darwin", "work", "linux darwin", "", "")
        )

    def test_profile_mismatch(self):
        self.assertEqual(
            dotctl.skip_reason("claude", "darwin", "personal", "", "work", ""),
            "profile: work",
        )

    def test_skip_wins(self):
        self.assertEqual(
            dotctl.skip_reason("rofi", "linux", "personal", "linux", "", "rofi"),
            "config: SKIP",
        )


if __name__ == "__main__":
    unittest.main()
