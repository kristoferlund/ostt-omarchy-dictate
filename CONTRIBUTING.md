# Contributing

Thanks for helping improve OSTT Dictation for Omarchy. Bug reports, fixes, and
improvements are all welcome.

## Before You Start

- **Bugs:** open an issue with the bug report template. Include the versions it asks for and the notification or error you saw.
- **Small fixes:** go straight to a pull request.
- **New features or larger changes:** open an issue first so we can agree on the approach before you spend time on it.
- **Problems with transcription, models or agents themselves** usually belong in [OSTT](https://github.com/kristoferlund/ostt/issues). This repo is the Omarchy integration.
- **Security issues:** do not open a public issue. See [SECURITY.md](SECURITY.md).

## Project Principles

Changes should fit these principles:

- **Never hang, never lose words.** Every step has a time limit, and a failure ends in a notification that says what went wrong. When processing fails, the words are pasted as heard.
- **OSTT does the work.** Transcription, processing actions and agents live in OSTT and are reached through its CLI. The plugin records, shows state, and hands over.
- **Agents never get tools.** Context-aware dictation runs agents only through OSTT, which switches their tools off. Treat everything from the screen or the transcript as untrusted.
- **Nothing on screen leaves without consent.** Screenshots are off unless the user turns them on for that app, and stay in `$XDG_RUNTIME_DIR`.
- **Respect the user's files.** Only change the lines the plugin owns in `ostt.toml`, `dictate.toml` and the Omarchy menu extension.
- **Follow Omarchy.** Use its commands (`omarchy-pkg-add`, `omarchy-dictation-use`, notifications) and theme colors instead of reimplementing them.

## Development Setup

Clone the repository and install it from your checkout:

```bash
git clone https://github.com/kristoferlund/ostt-omarchy-dictate.git
cd ostt-omarchy-dictate
omarchy plugin add "$PWD" --enable
```

Then click the microphone in the bar to run the setup. After changing QML
files, run `omarchy restart shell` to load them. Changes to the scripts in
`bin/` take effect on the next dictation.

## Validation

Run these before opening a pull request:

```bash
omarchy plugin validate .
python -m unittest discover -s tests
shellcheck -x bin/* install uninstall lib/*.sh
```

CI runs the tests, the shell checks and a manifest check on every pull request.
It cannot run the plugin inside `omarchy-shell` or record from a microphone, so
also try your change with a real dictation: plain, with a processing action,
and cancelled.

Parsing belongs in `lib/`, where it can be tested. If you change how
`dictate.toml` or OSTT's errors are read, add a test case in `tests/` with the
input that triggered the change.

## Pull Requests

- Keep each pull request focused on one change.
- Explain what was wrong and how you tested it: which Omarchy and OSTT versions.
- Include a screenshot for visible changes to the popup, widget or card.
- Add an entry under `## [Unreleased]` in [CHANGELOG.md](CHANGELOG.md) for user-facing changes.
- Leave the `version` in `manifest.json` alone. The maintainer bumps it when releasing.
- Write commit subjects in the imperative mood and keep them under about 72 characters, for example `Close the popup as soon as the text is pasted`.

AI-assisted contributions are welcome. You are responsible for every line you
submit, so review the code yourself and test it on a real Omarchy desktop.

Pull requests are usually squash-merged.

## Releases

The maintainer releases by moving the `Unreleased` entries in `CHANGELOG.md`
into a new version section, bumping `version` in `manifest.json`, tagging
`vX.Y.Z`, and publishing a GitHub release with the changelog notes.

## License

By contributing, you agree that your contributions are licensed under the
[MIT License](LICENSE).
