# CLAUDE.md

Orientation for Claude working on LeRep. Read this first.

## What this is

A WoW: Forever addon (Lua, interface 16001) that plans the cheapest gold path
to a rank and an amount of Merchant's Favor with the trade factions (Azeroth
Commerce Authority / Durotar Supply and Logistics). A sibling of leprofit
(`addohm/leprofit`): same stack, look, tools and release pattern. The agreed
design is in ROADMAP.md; no code yet. The remote is `addohm/LeRep` on GitHub
(pushed via the `deploy-ws-LeRep` deploy key); releases go to CurseForge and
Wago.

Discuss each feature with the owner before building it.

## Layout

- `README.md`, `CHANGELOG.md`, `DEPLOY.md`, `SECURITY.md`, `ROADMAP.md`: the
  standard docs
- `CLAUDE.md`: this file

Add a line for each folder or key file as code arrives.

## Workflow

1. Start from the latest: pull before changing anything.
2. Make the change with tests.
3. **Update the docs in the same commit.** Every change updates the docs it
   affects:
   - README.md: setup and usage
   - CHANGELOG.md: an entry under *Unreleased*
   - DEPLOY.md: when deploying or running it live changes
   - SECURITY.md: when secrets, access or permissions change
   - ROADMAP.md: when something on it is done, or new plans are made
   - this file: when the layout, workflow or conventions change
4. Run the checks (none yet; they'll be leprofit's: `tests/run_tests.py`
   with lupa), then commit. Push when asked; say "Pushed: <commit>" after
   each push.

## Conventions

- Branch: `main`.
- Changelog follows Keep a Changelog; versions follow SemVer.
- Follow leprofit's conventions: Lua for Forever's Midnight addon limits
  (guard secret values), tabs, a comment at the top of each file, comments
  that explain why. Settings per character.
- Per-step detail goes in tooltips first; add a column only for things worth
  sorting by (the owner's rule from leprofit).
- The version and build show in chat only, never in the window.

## Don't

- Commit secrets (`.env`, keys, tokens).
- Name the levelling-planner addon leprofit's data came from, in anything
  committed (code, data, docs, commit messages).
- Use Season of Discovery's "Waylaid Supplies" items or rep numbers: they're
  still in Forever's game files but not used by Forever.
