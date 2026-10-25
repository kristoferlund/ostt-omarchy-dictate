"""Tests for the catalogs in i18n/. Run with: python3 -m unittest discover tests"""

import glob
import json
import os
import re
import unittest

ROOT = os.path.join(os.path.dirname(__file__), "..")


def catalog(path):
    with open(path, encoding="utf-8") as f:
        return json.load(f)


class Catalogs(unittest.TestCase):
    """A key missing from en.json shows as the raw key in every language, and
    a translation that drops a %1 drops the error it was meant to show."""

    def setUp(self):
        self.english = catalog(os.path.join(ROOT, "i18n", "en.json"))

    def test_every_key_the_qml_reads_is_in_english(self):
        used = set()
        for path in glob.glob(os.path.join(ROOT, "*.qml")):
            with open(path, encoding="utf-8") as f:
                used |= set(re.findall(r'strings\.tn?\("([^"]+)"', f.read()))
        self.assertTrue(used)
        self.assertEqual(used - set(self.english), set())
        self.assertEqual(set(self.english) - used, set(), "unused keys")

    def test_translations_match_english(self):
        for path in glob.glob(os.path.join(ROOT, "i18n", "*.json")):
            with self.subTest(os.path.basename(path)):
                strings = catalog(path)
                self.assertEqual(set(strings), set(self.english))
                for key, text in strings.items():
                    self.assertEqual(
                        sorted(re.findall(r"%\d", text)),
                        sorted(re.findall(r"%\d", self.english[key])),
                        key,
                    )


if __name__ == "__main__":
    unittest.main()
