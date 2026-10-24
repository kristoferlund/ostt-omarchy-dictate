"""Tests for lib/ostt-error.sh. Run with: python3 -m unittest discover tests"""

import os
import subprocess
import unittest

LIB = os.path.join(os.path.dirname(__file__), "..", "lib", "ostt-error.sh")


def ostt_error(stderr, fallback=""):
    return subprocess.run(
        ["bash", "-c", 'source "$0"; ostt_error "$1" "$2"', LIB, stderr, fallback],
        capture_output=True, text=True, check=True,
    ).stdout


class OsttError(unittest.TestCase):
    """Notifications show ostt's error as the README's scripting contract
    describes it: `Error: ` and its causes, or clap's `error: `, without the
    log lines around them."""

    def test_keeps_the_message_and_its_causes(self):
        stderr = (
            "2026-10-24 INFO starting\n"
            "Error: Processing failed, so the transcription was output unprocessed\n"
            "\n"
            "Caused by:\n"
            "    0: Agent 'claude' failed (exit code 1):\n"
            "    1: Not logged in\n"
        )
        self.assertEqual(
            ostt_error(stderr),
            "Processing failed, so the transcription was output unprocessed\n"
            "Agent 'claude' failed (exit code 1):\n"
            "Not logged in",
        )

    def test_a_single_cause_has_no_number(self):
        stderr = "Error: No model selected\n\nCaused by:\n    run ostt model\n"
        self.assertEqual(ostt_error(stderr), "No model selected\nrun ostt model")

    def test_a_command_line_error_from_clap(self):
        stderr = "error: unrecognized subcommand 'agent'\n\nUsage: ostt [OPTIONS]\n"
        self.assertEqual(ostt_error(stderr), "unrecognized subcommand 'agent'")

    def test_falls_back_to_the_last_line_then_the_default(self):
        self.assertEqual(ostt_error("something\nwent wrong\n\n"), "went wrong")
        self.assertEqual(ostt_error("", "Transcription failed."), "Transcription failed.")

    def test_a_long_error_is_cut(self):
        self.assertEqual(len(ostt_error("Error: " + "x" * 1000)), 401)


if __name__ == "__main__":
    unittest.main()
