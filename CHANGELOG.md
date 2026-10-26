# Changelog

All notable changes to OSTT Dictation for Omarchy are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project uses [Semantic Versioning](https://semver.org/spec/v2.0.0.html). The version in `manifest.json` matches the latest release.

## [Unreleased]

Initial release.

### Added

- OSTT as an Omarchy 4.5 dictation backend, listed in Setup > Defaults > Dictation and driven by Omarchy's dictation keys: hold Right Alt or F9, toggle with Super + Ctrl + X, cancel with Super + Ctrl + Alt + X.
- A setup, from the bar or the dictation menu, that installs OSTT from the AUR with the build for your hardware (CUDA, Vulkan or CPU), asks for a transcription model, offers to keep a local model loaded, and offers context-aware dictation. An OSTT older than 0.0.31 can be replaced by the AUR package, whether it came from another OSTT package, OSTT's install script, or both.
- A recording popup with a live level meter, and cancel and finish buttons, in the theme's colors. It never takes keyboard focus.
- Media players that are playing pause while you record and resume afterwards, with a switch in the widget's card to turn it off.
- A bar widget that shows whether OSTT is recording or transcribing, with a card for choosing each app's processing action and whether it gets a screenshot of the window.
- The widget and card follow the language picked under Setup > Language, in English, Simplified Chinese, Spanish, Brazilian Portuguese, German and Russian.
- Ghostwriter and Text cleanup processing actions, added to OSTT with the agent and model you choose.
- `ostt-dictate`, the recorder behind the keys, popup and widget, with `status --json --follow` for other tools.

[Unreleased]: https://github.com/kristoferlund/ostt-omarchy-dictate/commits/main
