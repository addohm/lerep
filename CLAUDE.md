# CLAUDE.md

Orientation for Claude working on LeRep. Read this first.

## What this is

LeRep has no code yet: the repo holds only the standard docs. Source is on
GitHub at `addohm/LeRep` (pushed via the `deploy-ws-LeRep` deploy key).

TODO: what is LeRep? The name matches the Forever addons (leboof, leproc,
leprofit) — is it a reputation addon, and should it follow their release
pattern?

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
4. Run the checks (none yet; TODO: the lint and test commands once there's code), then commit.

## Conventions

- Branch: `main`.
- Changelog follows Keep a Changelog; versions follow SemVer.
- TODO: coding style and naming, once the language is chosen.

## Don't

- Commit secrets (`.env`, keys, tokens).
