"""Tests for lib/dictate_config.py. Run with: python3 -m unittest discover tests"""

import os
import sys
import tempfile
import tomllib
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "lib"))
import dictate_config as dc  # noqa: E402

ENTRY = {"action": "ghostwriter", "screenshot": True}


class Edit(unittest.TestCase):
    """dictate.toml is the user's file: an edit changes one app and keeps
    everything else as written, or refuses."""

    def test_keeps_comments_and_other_sections(self):
        text = '# mine\n[apps] # apps\n"foot" = { action = "clean" }\n\n[other]\nk = 1\n'
        result = dc.edit(text, "Slack", ENTRY)
        self.assertEqual(
            result,
            '# mine\n[apps] # apps\n"foot" = { action = "clean" }\n'
            '"Slack" = { action = "ghostwriter", screenshot = true }\n\n[other]\nk = 1\n',
        )

    def test_replaces_and_removes_an_entry(self):
        text = '[apps]\n"Slack" = { action = "clean" }\n'
        self.assertIn('"Slack" = { action = "ghostwriter", screenshot = true }', dc.edit(text, "Slack", ENTRY))
        self.assertEqual(dc.edit(text, "Slack", None), "[apps]\n")

    def test_keeps_crlf_line_endings(self):
        result = dc.edit('[apps]\r\n"a" = { action = "x" }\r\n', "b", ENTRY)
        self.assertEqual(result.count("\r\n"), 3)
        self.assertNotIn("\n", result.replace("\r\n", ""))

    def test_leaves_keys_with_toml_only_escapes_alone(self):
        text = '[apps]\n"K\\U0001F600" = { action = "x" }\n'
        result = dc.edit(text, "Slack", ENTRY)
        self.assertTrue(result.startswith(text))

    def test_creates_the_table_in_an_empty_file(self):
        self.assertEqual(
            dc.edit("", "Slack", ENTRY),
            '[apps]\n"Slack" = { action = "ghostwriter", screenshot = true }\n',
        )

    def test_refuses_an_edit_that_would_change_anything_else(self):
        # The line looks like Slack's entry but belongs to a multi-line string.
        text = '[apps]\nnote = """\n"Slack" = "x"\n"""\n"Slack" = { action = "clean" }\n'
        with self.assertRaises(dc.ConfigError):
            dc.edit(text, "Slack", None)

    def test_refuses_invalid_toml(self):
        with self.assertRaises(dc.ConfigError):
            dc.edit("[apps\n", "Slack", ENTRY)


class EditPauseMedia(unittest.TestCase):
    """pause_media is a top-level key: it must go before the first table, or
    TOML would read it as an app under [apps]."""

    def test_adds_it_before_the_first_table(self):
        text = '# mine\n[apps]\n"foot" = { action = "clean" }\n'
        self.assertEqual(dc.edit_pause_media(text, False),
                         '# mine\npause_media = false\n\n[apps]\n"foot" = { action = "clean" }\n')

    def test_replaces_it_in_place(self):
        text = 'pause_media = true # mine\n\n[apps]\n'
        self.assertEqual(dc.edit_pause_media(text, False), 'pause_media = false\n\n[apps]\n')

    def test_leaves_a_pause_media_app_alone(self):
        text = '[apps]\npause_media = { action = "clean" }\n'
        result = dc.edit_pause_media(text, False)
        self.assertEqual(tomllib.loads(result),
                         {"pause_media": False, "apps": {"pause_media": {"action": "clean"}}})

    def test_writes_an_empty_file(self):
        self.assertEqual(dc.edit_pause_media("", True), "pause_media = true\n")


class Read(unittest.TestCase):
    def setUp(self):
        self.dir = tempfile.TemporaryDirectory()
        self.path = os.path.join(self.dir.name, "dictate.toml")

    def tearDown(self):
        self.dir.cleanup()

    def write(self, text):
        with open(self.path, "w") as f:
            f.write(text)

    def test_a_malformed_entry_affects_only_its_app(self):
        self.write('[apps]\nSlack = { action = "ghostwriter", screenshot = true }\nOld = "ghostwriter"\n')
        self.assertEqual(dc.apps(self.path), {"apps": {"Slack": ENTRY}, "invalid": ["Old"], "pause_media": True})
        self.assertEqual(dc.lookup(self.path, "Slack"), ENTRY)
        self.assertEqual(dc.lookup(self.path, "Firefox"), {})
        with self.assertRaisesRegex(dc.ConfigError, "Old"):
            dc.lookup(self.path, "Old")

    def test_a_missing_file_has_no_apps(self):
        self.assertEqual(dc.apps(self.path), {"apps": {}, "invalid": [], "pause_media": True})

    def test_screenshot_defaults_to_off(self):
        self.write('[apps]\nfoot = { action = "clean" }\n')
        self.assertEqual(dc.lookup(self.path, "foot"), {"action": "clean", "screenshot": False})

    # Which apps send screenshots to an agent is the user's own business, even
    # in a file an older setup left readable by others.
    def test_map_writes_atomically_and_privately(self):
        self.write('[apps]\n')
        os.chmod(self.path, 0o644)
        dc.map_app(self.path, "Slack", "ghostwriter", True)
        with open(self.path, "rb") as f:
            self.assertEqual(tomllib.load(f)["apps"]["Slack"], ENTRY)
        self.assertEqual(os.stat(self.path).st_mode & 0o777, 0o600)
        self.assertEqual(os.listdir(self.dir.name), ["dictate.toml"])

    def test_pause_media_is_on_unless_set_to_false(self):
        self.assertIs(dc.pause_media({}), True)
        self.assertIs(dc.pause_media({"pause_media": False}), False)
        # Not valid: reported by apps, and dictation still pauses.
        self.write('pause_media = "no"\n')
        self.assertIsNone(dc.apps(self.path)["pause_media"])

    def test_pause_media_switch_keeps_the_apps(self):
        self.write('[apps]\nfoot = { action = "clean" }\n')
        dc.main(["pause-media", self.path, "off"])
        with open(self.path, "rb") as f:
            self.assertEqual(tomllib.load(f), {"pause_media": False, "apps": {"foot": {"action": "clean"}}})
        with self.assertRaises(dc.ConfigError):
            dc.main(["pause-media", self.path, "maybe"])

    def test_map_refuses_an_option_as_the_action_or_no_class(self):
        with self.assertRaises(dc.ConfigError):
            dc.main(["map", self.path, "Slack", "--screenshot"])
        with self.assertRaises(dc.ConfigError):
            dc.main(["map", self.path, "", "clean"])


if __name__ == "__main__":
    unittest.main()
