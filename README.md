# OSTT Dictation for Omarchy

Make [OSTT](https://ostt.ai) the dictation tool behind Omarchy's own dictation
keys. Hold Right Alt or F9 and speak; OSTT transcribes on your own machine, or
with a cloud model if you prefer, and pastes the text into the app you are
typing in. No terminal opens.

In the apps you choose, dictation also takes instructions. Say "reply saying I
can't make it" in Slack, and **Ghostwriter**, running on the AI agent you
already use, reads the window and writes the reply.

📖 **[Documentation](https://ostt.ai/guide/platforms/omarchy-dictation)** ·
[Overview](https://ostt.ai/omarchy) · [OSTT](https://github.com/kristoferlund/ostt)

## Features

- Works with Omarchy's dictation keys, and is listed in **Setup > Defaults > Dictation**
- Local transcription with Parakeet or Whisper, with GPU support, or any cloud model OSTT supports
- A recording popup with a live level meter, and cancel and finish buttons
- A bar widget that shows when OSTT is recording or transcribing
- Context-aware dictation per app: a processing action, and optionally a screenshot of the window
- Ghostwriter and Text cleanup actions, running on Claude Code, Codex, OpenCode or another agent CLI, with its tools switched off
- Falls back to your words as heard when the agent fails, so nothing is lost

## Requirements

- Omarchy 4.5 or later
- OSTT 0.0.31 or later for context-aware dictation; the setup installs OSTT if it is missing
- For context-aware dictation, an agent CLI you are signed in to; `ostt agent list` shows which ones OSTT can run

## Install

```bash
omarchy plugin add https://github.com/kristoferlund/ostt-omarchy-dictate.git --enable
```

Then click the microphone that appears in the bar. It opens the setup in a
terminal, which:

- installs OSTT if it is missing, with `ffmpeg`, `python`, `wtype` and `grim`.
  It picks the build for your hardware: `ostt-cuda-bin` when Arch's `cuda` 13
  is installed and the NVIDIA GPU supports it, `ostt-vulkan-bin` where Vulkan
  works, and `ostt-bin` otherwise;
- asks for a transcription model if none is selected, and for a local model
  offers to keep it loaded so dictation starts instantly;
- offers context-aware dictation;
- makes OSTT Omarchy's dictation backend.

Afterwards OSTT is listed in Setup > Defaults > Dictation. Selecting it there
runs the setup again, to finish one you stopped or to change your answers.
Running `~/.config/omarchy/plugins/io.github.kristoferlund.ostt-dictate/install`
does the same.

## Use

| Key | Action |
| --- | --- |
| Right Alt or F9 (hold) | Record while held, paste on release |
| Super + Ctrl + X | Start, or stop and paste |
| Super + Ctrl + Alt + X | Cancel without pasting |

OSTT records from the default input device; pick it in Omarchy's audio
settings.

While you dictate, a pill at the bottom of the screen shows a live level meter
between two buttons: ✕ cancels the recording, and ✓ stops it and transcribes.
During transcription the meter becomes a moving wave and the ✓ a spinner; the
pill fades out once the text is pasted. It takes its colors from your theme,
and never takes keyboard focus, so the text lands in the app you were typing
in.

A failed transcription keeps the recording, and the notification tells you how
to retry it. If only the processing action fails, OSTT pastes your words as
heard and the notification says why.

## Context-Aware Dictation

In apps you choose, dictation sends your words to a processing action, and if
you allow it, a screenshot of the window too. Every other app keeps plain
transcription. No screenshot is taken unless you turn it on for that app.

The setup offers it, and adds two processing actions to
`~/.config/ostt/ostt.toml` using the agent and model you pick. Edit their
prompts there:

- **Ghostwriter** (`ghostwriter`) tidies up your words and carries out spoken
  instructions such as "finish this sentence as a haiku" or "reply saying I
  can't make it". With the screenshot on, it also matches names, terms and
  tone on screen.
- **Text cleanup** (`clean`) only fixes misheard words, punctuation and filler.

If you already have an action with one of those ids, the setup uses it as it
is. The actions run the agent with a 60-second limit (`timeout_secs`), and name
its program by the path the setup found (`tool_binary`), so dictation finds it
whatever PATH the desktop session has. If the agent later moves (an upgrade
into a new version folder, say) and dictation says its program is not found,
correct or remove `tool_binary` in those actions.

### Choose the Apps

Right-click the microphone in the bar. The card lists the apps on the visible
workspaces, and any already set up, with their current settings. Click a row,
or move to it with the arrow keys and press Enter, to expand it and choose one
of your processing actions, and whether to send a screenshot. The choice
applies to every window of that app.

It is saved in `~/.config/ostt/dictate.toml` by Hyprland window class, which
you can also edit by hand (`screenshot` defaults to `false`):

```toml
[apps]
"Slack" = { action = "ghostwriter", screenshot = true }
"thunderbird" = { action = "my-own-action" }
```

Any processing action works, including your own. A bash action gets the
screenshot's path in `$OSTT_ATTACHMENT`.

### Agents and Screenshots

The setup offers the agents OSTT knows how to run with their tools switched
off, so text on screen can't make them run commands or touch files. The card
offers the screenshot only for actions that can use it, and an app set by hand
to send one to an action that cannot is dictated without it, with a
notification. If something is wrong with an app's entry, or the screenshot
fails, that dictation falls back to plain transcription and a notification
says why.

The agent takes a few seconds, and the text is pasted into whichever window is
focused when it finishes. Super + Ctrl + Alt + X cancels a dictation that is
taking too long.

The screenshot is a capture of the window's area of the screen, so anything on
top of it, such as a notification, is included. It is kept in
`$XDG_RUNTIME_DIR/ostt-dictate` (readable only by you) until the dictation
finishes, and after a failure until the next dictation, so the retry command in
the notification works.

## Bar Widget

| State | Icon |
| --- | --- |
| Not set up | Microphone; click it to run the setup |
| Idle | Dimmed microphone |
| Recording | Microphone in the bar's alert color |
| Transcribing | Hourglass |
| Failed | Crossed-out microphone for 15 seconds; the tooltip has the error |

Left-click starts dictation, or stops it and pastes into the focused app.
Right-click cancels a recording or a pending transcription; otherwise it opens
the list of apps with their processing action and screenshot setting.

| Setting | Default | Meaning |
| --- | --- | --- |
| `hideWhenIdle` | `false` | Show the widget only while recording, transcribing, or right after an error |

## Update

```bash
omarchy plugin update io.github.kristoferlund.ostt-dictate --yes
```

Without `--yes`, Omarchy shows the code changes and asks first. The bar widget
and the recording popup keep their old version until the shell restarts: run
`omarchy restart shell`, or log out and back in.

## Remove

```bash
~/.config/omarchy/plugins/io.github.kristoferlund.ostt-dictate/uninstall
omarchy plugin remove io.github.kristoferlund.ostt-dictate
```

`uninstall` switches dictation away from OSTT and removes the scripts. OSTT
itself stays installed (remove it with `omarchy pkg remove ostt-bin`, or the
package you have), and so do `~/.config/ostt/dictate.toml` and the
`ghostwriter` and `clean` actions in `ostt.toml`.

## Command Line

`ostt-dictate` is the recorder behind the keys, the popup and the widget:

```
ostt-dictate start | stop | toggle | cancel
ostt-dictate status [--json] [--follow]
ostt-dictate levels
ostt-dictate apps
ostt-dictate map <class> [<action> [--screenshot]]
```

Each command returns at once; recording and transcription run in the
background. `status --json --follow` prints a line such as
`{"state":"recording"}` whenever the state changes. The states are `idle`,
`recording`, `transcribing` and `error`. `levels` follows the input level as
ffmpeg's `RMS_level` lines in dBFS, for the popup's meter. `apps` prints, as
JSON, OSTT's processing actions and the apps on the visible workspaces or in
`dictate.toml` with their settings, for the card; `map` sets or clears one
app's action and screenshot, changing only that line of `dictate.toml`.

## How It Fits Together

| Part | What it does |
| --- | --- |
| `bin/ostt-dictate` | Records from the default microphone without a terminal and hands the recording to `ostt transcribe --paste` |
| `bin/omarchy-*-dictation-ostt` | The Omarchy dictation backend: run `ostt-dictate` from Omarchy's keys, set it up, and remove it |
| `Popup.qml`, `Pill.qml` | The recording popup |
| `Widget.qml` | The bar widget and the per-app card |
| `lib/` | `dictate.toml` handling and OSTT error messages |
| `i18n/` | The widget's and card's text in English, Simplified Chinese, Mexican Spanish, Brazilian Portuguese, German and Russian; other languages fall back to English |
| `actions/` | The processing actions the setup adds to OSTT |
| `install`, `uninstall` | Link the scripts into `~/.local/bin` and list OSTT in Omarchy's dictation menu, or undo that |

## Contributing

Contributions are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md) for the
development setup, the checks to run before a pull request, and guidelines,
and [CHANGELOG.md](CHANGELOG.md) for release history. Report security issues
privately as described in [SECURITY.md](SECURITY.md).

## License

[MIT](LICENSE)
