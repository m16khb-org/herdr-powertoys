# herdr-powertoys

Layout helpers for [Herdr](https://herdr.dev) split panes, in the spirit of
PowerToys FancyZones: one key makes every pane in a tab the same size.

| Action | What it does | Default key |
| --- | --- | --- |
| `equalize` | Every pane in each row and column of the focused tab gets the same size. Two panes become exactly 50 : 50, three columns a third each, and a column stacked into rows counts as one column. | `prefix+=` |
| `cycle` | The focused pane's share of its split steps 1/2 → 2/3 → 1/3 → 1/2. | `prefix+plus` |
| `half` | The split that holds the focused pane goes to exactly 1/2. | (commented out, `prefix+0`) |

Herdr's own resize keys move a border one step at a time, so they cannot land
on an exact ratio. These actions set the ratio itself.

## Install

```bash
herdr plugin install m16khb-org/herdr-powertoys
herdr plugin action invoke setup-keys --plugin m16khb.herdr-powertoys
```

`setup-keys` writes one marker-fenced block into your Herdr config. It backs
the file up to `config.toml.powertoys-backup` first, leaves keys you already
bound alone, checks the result with `herdr config check` (restoring the
backup if that fails), and reloads the config. `remove-keys` deletes the
block. To bind your own keys instead, point a `[[keys.command]]` entry with
`type = "plugin_action"` at `m16khb.herdr-powertoys.equalize`, `.cycle` or
`.half`.

Requirements: Herdr 0.9.3 or newer on macOS or Linux, and Perl 5 with its core
modules (`JSON::PP`, `IO::Socket::UNIX`), which ship with macOS and with
Perl on Linux. Nothing else is installed. Windows is not supported: there the
Herdr socket is a named pipe.

## How it works

The Herdr CLI has no command that sets a split ratio, but the socket API does.
Each action reads the focused tab with `layout.export` and sets ratios with
`layout.set_split_ratio`. `equalize` gives each split the share that its first
child's pane count is of the total along the split direction, so nested
same-direction splits end up even.

```text
lib/Herdr/Powertoys.pm   layout arithmetic (no I/O)
bin/powertoys.pl         the actions: socket calls and messages
herdr/keys.sh            setup-keys / remove-keys
t/layout.t               tests: prove -l t
```

Messages go to `herdr plugin log m16khb.herdr-powertoys`. They are also sent
as a Herdr notification when notifications are on.

## License

MIT
