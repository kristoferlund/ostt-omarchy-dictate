# Security Policy

## Supported Versions

Security fixes are released for the latest version only.

## Reporting a Vulnerability

Do not open a public issue for security problems. Instead, report them
privately through GitHub's
[private vulnerability reporting](https://github.com/kristoferlund/ostt-omarchy-dictate/security/advisories/new).

Please include:

- What the issue is and what an attacker could do with it.
- Steps or a proof of concept to reproduce it.
- The plugin version, OSTT version and Omarchy version.

You should get a response within a week. Once a fix is released, the advisory
is published and you are credited, unless you prefer otherwise.

Report problems in OSTT itself, such as how it runs agents, here too. They
are passed on and fixed there.

## Scope

The plugin runs with user permissions. It records from the microphone, takes
screenshots of windows the user has chosen, and passes both to OSTT, which may
send them to an AI agent. Issues worth reporting include:

- A way for text on screen or in a dictation to make an agent run commands, read or change files, or reach the network beyond its own API.
- A screenshot taken for an app the user has not turned it on for, or kept beyond the dictation and the retry after a failure.
- Recordings or screenshots readable by other users.
- Command or argument injection through window classes, action ids, `dictate.toml` or OSTT's output.
- Changes to the user's files outside the lines the plugin owns.
