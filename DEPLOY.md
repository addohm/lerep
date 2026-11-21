# Deploying leRep

leRep is a World of Warcraft addon: it runs inside the game client (WoW:
Forever, Interface 16001), and there's no server. Releases are published on
both CurseForge and Wago, from `release/` with the text and images in
`LISTING.md`. The source is public on GitHub under the GNU GPLv3.

## First-time setup

On the Windows test PC:

1. Clone the repo anywhere: `git clone https://github.com/addohm/lerep.git` (it needs your GitHub
   login if the repo is private).
2. Open `tools\install_forever.cmd` and check `WOW` at the top: it's the client folder, by default
   `C:\Program Files (x86)\World of Warcraft\_forever_`, the live game.
3. Run `tools\install_forever.cmd` from a terminal, then start the game and tick leRep in the
   AddOns list.

To install by hand instead, copy the `leRep` folder (not the repo root) into
`<WoW>\_forever_\Interface\AddOns\`.

## Shipping a change

1. Run the tests: `.venv/bin/python tests/run_tests.py`.
2. Commit and push.
3. On Windows, run `tools\install_forever.cmd`, then `/reload` (or restart the game if it says so).
4. For a release: bump `## Version` in `leRep/leRep.toc`, move the CHANGELOG's Unreleased entries
   under the new version, and commit. Then `python3 tools/make_release.py` writes
   `release/leRep-<version>.zip` from the last commit (it refuses if `leRep/` has uncommitted
   changes); commit the zip, tag (`git tag v0.9.0-beta`) and push with `--tags`. Upload the zip to
   CurseForge and to Wago, each with `LISTING.md`'s release notes; the summary, description,
   categories and images are there too. If the icon changed, `python3 art/make_logo.py` redraws
   it (and `leRep/Media/Icon.tga`).

## The install script

`tools\install_forever.cmd` (from leprofit's) does, in order:

- `git pull --ff-only` (it only gets what's pushed, so push first). The pull can update the
  script itself, so it runs from a copy in `%TEMP%`. If the pull fails because GitHub's history was
  rewritten (this copy's last commit isn't in it any more), it says so and prints the two commands
  that move the copy onto GitHub's: `git fetch origin --tags --force` and
  `git reset --hard origin/main` (they throw away commits and edits made only in the copy).
- Removes an installed `LeRep\` or `Lerep\` folder from builds before the renames (Windows ignores letter
  case, so copying over it would keep the old spelling).
- Mirrors `leRep\` into `<WOW>\Interface\AddOns\leRep\` (`robocopy /MIR`), creating it on the
  first run. If `WOW` itself doesn't exist it stops, since the path is probably wrong.
- Writes the commit into the installed `leRep\Build.lua`, so `/lerep help` shows
  `v<version> build <commit>`. "-dirty" means the copy included uncommitted changes.
- Packs `leRep-<version>.zip` on the desktop: `git archive` of the committed addon, without the
  build stamp.
- Says whether `/reload` is enough. WoW reads an addon's file list only when the game starts, so
  when `leRep.toc` changed you must restart the game.

If creating or copying fails, the WoW folder may need the script to run as administrator. The
script needs CRLF line endings to run reliably; `.gitattributes` makes git check it out that way.

## Refreshing the data

`python3 tools/fetch_sources.py` downloads the newest Forever build's game
data and every build of Efficient Games' player data into `.source/`; then
`python3 tools/gen_data.py` rewrites `leRep/Data.lua`. Check its summary line
(150 writs and 30 crates so far), run the tests, and commit the new
`Data.lua`.

## Rolling back

Install an older version: `git checkout <tag> -- leRep` in the clone, copy the folder over the
installed one, then `git checkout main -- leRep` to return.

## Configuration

There are no secrets or environment settings. In-game settings are per character, in
`WTF/Account/<account>/<realm>/<character>/SavedVariables/leRep.lua`. Vendor prices and what leRep
has seen (the receipt's price, crate Favor, Coin Pouches) are shared by your characters, in
`WTF/Account/<account>/SavedVariables/leRep.lua`.

## Troubleshooting

- **Nothing on `/lerep`:** the addon isn't loaded. Check the AddOns list; if it says out of date,
  the client's Interface number isn't 16001.
- **Empty plans, or "no price" warnings:** `/lerep status` says which price addons it found.
  Without Auctionator (or TSM) there are no auction prices; with it, scan the auction house.
- **Lua errors:** `/console scriptErrors 1` shows them; report them with the `/lerep help` build.
