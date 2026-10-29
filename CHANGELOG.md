# Changelog

All notable changes to OSTT Dictation for Omarchy are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project uses [Semantic Versioning](https://semver.org/spec/v2.0.0.html). The version in `manifest.json` matches the latest release.

## [0.1.1] - 2026-10-29

### Changed

- Requires OSTT 0.0.33, which keeps your dictation history, recordings, logs and API keys readable only by you. The setup offers to update an older OSTT.

### Fixed

- An action with no agent of its own that runs on GitHub Copilot through OSTT's `default_tool` is no longer run, as Copilot gets your words as a command-line argument.
- Without `XDG_RUNTIME_DIR`, dictation keeps the recording and screenshot in a folder under `/tmp` only if it is yours and not a link, so another user cannot read or swap it.
- Opening the widget's card no longer passes the titles of your windows in command-line arguments, where other users could read them.

## [0.1.0] - 2026-10-28

Initial release.

### Added

- OSTT as an Omarchy 4.5 dictation backend, listed in Setup > Defaults > Dictation and driven by Omarchy's dictation keys: hold Right Alt or F9, toggle with Super + Ctrl + X, cancel with Super + Ctrl + Alt + X.
- A setup, from the bar or the dictation menu, that installs OSTT from the AUR with the build for your hardware (CUDA, Vulkan or CPU), asks for a transcription model, offers to keep a local model loaded, and offers context-aware dictation. An OSTT older than 0.0.32 can be replaced by the AUR package, whether it came from another OSTT package, OSTT's install script, or both.
- A recording popup with a live level meter, and cancel and finish buttons, in the theme's colors. It never takes keyboard focus.
- Media players that are playing pause while you record and resume afterwards, with a switch in the widget's card to turn it off.
- A bar widget that shows whether OSTT is recording or transcribing, with a card for choosing each app's processing action and whether it gets a screenshot of the window.
- The widget and card follow the language picked under Setup > Language, in English, Simplified Chinese, Spanish, Brazilian Portuguese, German and Russian.
- Ghostwriter and Text cleanup processing actions, added to OSTT with the agent and model you choose.
- Actions on an agent that takes the prompt as a command-line argument, such as GitHub Copilot, are never run, since other users on the computer could read your words there. Apps set to one are dictated without it, with a notification.
- `ostt-dictate`, the recorder behind the keys, popup and widget, with `status --json --follow` for other tools.

[0.1.0]: https://github.com/kristoferlund/ostt-omarchy-dictate/releases/tag/v0.1.0
