# Deploying LeRep

LeRep is a World of Warcraft addon: it runs inside the game client (WoW:
Forever, Interface 16001), and there's no server. Releases will be published
on CurseForge and Wago, like leprofit's. Nothing is built yet.

## First-time setup

Comes with 0.1.0: leprofit's `tools\install_forever.cmd`, adapted.

## Shipping a change

Comes with 0.1.0: tests, push, install script, `/reload`; releases as
leprofit's (`make_release.py`, tag, upload to both sites).

## Refreshing the data

`python3 tools/fetch_sources.py` downloads the newest Forever build's game
data and every build of Efficient Games' player data into `.source/`; then
`python3 tools/gen_data.py` rewrites `LeRep/Data.lua`. Check its summary line
(150 writs and 30 crates so far), run the tests, and commit the new
`Data.lua`.

## Configuration

No secrets. In-game settings will be per character, in the game's
SavedVariables.

## Troubleshooting

Comes with 0.1.0.
