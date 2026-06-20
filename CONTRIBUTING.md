# Contributing to rtfreporter

Thanks for taking the time to contribute! Issues and pull requests are
very welcome at <https://github.com/ichirio/rtfreporter>.

By participating in this project you agree to abide by its
[Code of Conduct](CODE_OF_CONDUCT.md).

## Becoming a contributor

There is **no application or invitation step** — anyone can contribute:

1. Open or comment on an [issue](https://github.com/ichirio/rtfreporter/issues)
   to report a bug or propose a change.  (Issue forms guide you: *Bug
   report* / *Feature request*.)
2. For anything non-trivial, agree the approach on the issue first.
3. Fork the repo, create a topic branch, make the change, and open a
   pull request (the PR template's checklist walks you through it).
4. Address review feedback; once CI is green and a maintainer approves,
   it is merged.

After a couple of merged, good-quality PRs you may be offered **write
access / maintainer status** (the ability to push branches, label issues,
and review PRs) — just ask, or it will be offered.  Contributions of every
size are valued, including docs, tests, and bug reports.

## Issue → merge lifecycle

```
issue ──▶ discuss / agree approach ──▶ branch off main ──▶ open PR
   ▲                                                          │
   │                                                          ▼
   └──────────────── (changes requested) ◀── review + green CI
                                                              │
                                                              ▼
                                                      merge to main
                                                       (issue closed
                                                        via "Closes #N")
```

* **Issue** — describe the problem/idea; a maintainer triages and labels it
  (`bug`, `enhancement`, `good first issue`, ...).
* **Branch + PR** — see *Branching & collaboration* below.  Reference the
  issue with `Closes #N` so it auto-closes on merge.
* **Review + CI** — all three GitHub Actions workflows must pass (see
  *Continuous integration*) and at least one maintainer approves.
* **Merge** — the maintainer merges to `main`; the branch is deleted.

## Execution-disposition labels (`exec:*`)

Issues carry two independent kinds of label.  The **type** labels (`bug`,
`enhancement`, `documentation`, …) say *what* the issue is.  The **`exec:`**
labels say *how it should be acted on* — in particular whether the project's
coding agent may pick it up.  The `exec:` prefix and a shared colour family keep
the two axes from being confused; at most one `exec:*` label applies at a time.

| Label | Meaning | Agent behaviour |
|-------|---------|-----------------|
| `exec:agent`  | Pre-approved for the agent to implement. | The agent works the issue (issue → branch → PR). |
| `exec:human`  | A human will do this; the **assignee** names who. | The agent does **not** act. |
| `exec:hold`   | Pending a maintainer decision. | The agent does **not** act; it only reports that the issue exists. |
| `exec:wontdo` | Decided not to implement. | Ignored (or proposed for closing). |

An issue with **no** `exec:*` label is treated like `exec:hold`: the agent
reports it but does not start work.  To hand a freshly-filed (e.g. web-created)
issue to the agent, add `exec:agent`.

**Future agents.**  While there is a single agent, `exec:agent` is unambiguous.
When more than one agent exists, split it into suffixed labels
(`exec:agent-claude`, `exec:agent-codex`, …) so each agent picks up only its own.

## Reporting bugs

Open an issue at
<https://github.com/ichirio/rtfreporter/issues> and include:

- A short description of what you expected vs. what happened.
- A **minimal reproducible example** (a `reprex::reprex()` is ideal):
  the smallest self-contained snippet that triggers the problem.
- The output of `sessionInfo()` (R version, OS, package versions).
- For rendering problems, the offending `.rtf` (or the code that
  produces it) and, where possible, a screenshot of how it opens in
  Word / LibreOffice.

Please search existing issues first to avoid duplicates.

## Requesting features

Feature requests are welcome as issues. Clinical TFL use cases are the
primary focus, so describing the real-world table/listing/figure you are
trying to produce helps a lot.

## Pull requests

1. **Discuss first** for anything non-trivial — open an issue so we agree
   on the approach before you invest time.
2. Fork the repository and create a topic branch off `main`.
3. Follow the existing code style (see below).
4. Add or update **tests** under `tests/testthat/` for any behaviour
   change, and **documentation** (roxygen2 comments) for any exported
   function.
5. Make sure the checks pass locally:

   ```r
   devtools::document()      # regenerate man/*.Rd (NAMESPACE is hand-managed)
   devtools::test()          # all tests must pass
   devtools::check()         # 0 errors / 0 warnings
   ```

6. Update `NEWS.md` (user-facing) and, for a major/minor change,
   `CHANGELOG.md`.
7. Open the pull request against `main` with a clear description and a
   reference to the related issue (e.g. `Closes #12`).

## Branching & collaboration

The project uses a simple **GitHub-flow** model — a single long-lived
branch plus short-lived topic branches.  This scales cleanly from one
contributor to several.

- **`main` is the single source of truth.**  It must always be
  releasable: green on all CI workflows (R-CMD-check, test-coverage,
  pkgdown) and `0 errors / 0 warnings` on `devtools::check()`.  The
  current *development version* lives here.
- **Direct commits to `main`.**  Branch protection is **not yet enabled**
  while the project has a single maintainer (so `main` currently accepts
  direct pushes).  As soon as there is more than one contributor it will be
  turned on: require a pull request, passing CI, and at least one approving
  review before merge.  Contributors should use a PR regardless.
- **One topic branch per change**, cut from the latest `main`.  Name it
  **`<type>/<issue>-<slug>`** -- lowercase, hyphen-separated, short
  (3-5 words):

  ```
  fix/42-empty-cell-newline       feat/57-read-tfrmt-tables
  docs/60-contributing-guide      refactor/12-gt-adapter
  ```

  * **`<type>`** uses the Conventional Commits vocabulary:
    `feat`, `fix`, `docs`, `chore`, `refactor`, `test`, `perf`, `ci`.
  * **`<issue>`** is the related issue number (omit only for quick
    exploratory work with no issue yet; add it once an issue exists).
    Note: use the bare number -- `#` is not allowed in branch names.
  * **`<slug>`** is a couple of words describing the change.

  Tip: GitHub's *Create a branch* button on an issue (the Development
  panel) generates a correctly-named, auto-linked branch for you.  Either
  way, put `Closes #<issue>` in the PR description so the issue closes on
  merge.

- **Umbrella (tracker) issues spanning several PRs.**  A large effort -- a
  multi-cut article, a docs sweep, a multi-batch refactor -- may land as
  **several PRs under one issue**, with that issue kept **open as a
  tracker** (precedents: #150 -> PR #151 + #153; #146 -> PR #147 + later
  cuts).  When you do this:

  * Each interim PR references the tracker with **`Refs #<issue>`** (not
    `Closes`), so merging it does **not** close the tracker.  The **final**
    PR may use `Closes #<issue>` (or close it by hand) once the whole scope
    is done.
  * Keep a **checklist in the issue body** of what is still outstanding, and
    add a short **dated progress comment** each time a PR lands, so the
    record survives even as the plan evolves.
  * Give each cut's branch a **scope segment** so sibling branches/PRs stay
    distinct: **`<type>/<issue>-<scope>-<slug>`** -- e.g.
    `docs/146-showcase-dm`, `docs/146-showcase-ae` -- and mirror the scope in
    the PR title (`Showcase (DM): ...`).

- **Keep branches small and short-lived.**  Rebase (or merge) the latest
  `main` into your branch regularly so the eventual PR is a small,
  reviewable diff with no stale conflicts.
- **Regenerate and commit derived files.**  Run `devtools::document()`
  and commit the updated `man/*.Rd` in the same PR.  `NAMESPACE` is
  **hand-managed** — edit it deliberately, do not let a tool overwrite it.
- **Merging.**  Squash- or merge-commit per the maintainer's preference;
  make sure the PR title/commit message is meaningful.  The branch is
  deleted after merge.
- **Releases are cut from `main`** by the maintainer via tags — see
  *Versioning & releases* below.  Day-to-day contributors do not tag or
  publish releases.
- **(Optional) maintenance branches.**  Only if an older major version
  must be patched after a newer major has shipped, create a long-lived
  `release/v<MAJOR>` branch for back-ports.  This is not needed during
  normal single-line development.

## Continuous integration (GitHub Actions)

Three workflows run on every push to `main` and on every pull request
(under `.github/workflows/`).  A PR is mergeable only when all three are
green.

| Workflow | File | What it does |
|----------|------|--------------|
| **R-CMD-check** | `R-CMD-check.yaml` | `R CMD check` on a matrix of OS / R versions (the standard `r-lib/actions` recipe).  Must be 0 errors / 0 warnings. |
| **test-coverage** | `test-coverage.yaml` | Runs the testthat suite under `covr` and uploads coverage to Codecov. |
| **pkgdown** | `pkgdown.yaml` | Builds the documentation site and (on `main` / on a published release) deploys it to the `gh-pages` branch. |
| **version-guard** | `version-guard.yaml` | Fails a PR that raises the **MINOR or MAJOR** position of `DESCRIPTION` `Version:` unless the PR carries the `release` label (see *Versioning & releases*). A PATCH bump or no change always passes. |
| **lint** | `lint.yaml` | Runs `lintr::lint_package()` and fails on any lint. Scope and rules are set by the repository-root `.lintr` (currently lints `R/` only). |

All three also accept `workflow_dispatch` (run-on-demand from the Actions
tab).  Releases additionally re-trigger pkgdown on `release: published`.
Before pushing, reproduce CI locally with `devtools::document()`,
`devtools::test()` and `devtools::check()`.

## Project tracking (GitHub Projects / labels)

Backlog and progress are tracked on GitHub so that, as the project grows
beyond a single maintainer, anyone can see *what is planned, what is in
flight, and who is acting on it* at a glance.  Three mechanisms work
together; each answers a different question.

### The three axes

| Mechanism | Answers | Source of truth for |
|-----------|---------|---------------------|
| **Labels** | *What kind* of work, and *who may act* | triage + agent dispatch |
| **Milestones** | *Which release* it targets | release planning |
| **Project board** | *What stage* it is at right now | day-to-day progress |

* **Labels.**  Two independent families (see *Execution-disposition labels*
  above): the **type** labels (`bug`, `enhancement`, `documentation`,
  `good first issue`, `help wanted`) and the **`exec:*`** labels
  (`exec:agent` / `exec:human` / `exec:hold` / `exec:wontdo`).  The `exec:*`
  label remains the **authoritative dispatch signal** — the board visualises
  status but never overrides who is allowed to start work.
* **Milestones** group issues for a target release (e.g. `v0.1.0`),
  mirroring the major/minor entries in `NEWS.md` / `CHANGELOG.md`.

### The board — "rtfreporter roadmap"

A single org/user-level **GitHub Projects (v2)** board gives the kanban view.
Issues *and* PRs are added as items; the board is for coordination only — the
record of *what shipped* stays in `NEWS.md` / `CHANGELOG.md`.

**Status** (single-select; the columns):

| Status | Meaning | Typical label/PR state |
|--------|---------|------------------------|
| **Backlog** | Captured, not yet scheduled. | no `exec:*`, or `exec:hold` |
| **Ready** | Approved and scoped; ready to pick up. | `exec:agent` / `exec:human` (assignee set) |
| **In progress** | Someone (or the agent) is actively working it. | branch exists |
| **In review** | PR open, CI green, awaiting review. | open PR |
| **Blocked** | Needs a decision or an upstream fix. | `exec:hold` |
| **Done** | Merged / closed. | issue closed via `Closes #N` |

**Custom fields** (so the board can be sliced):

* **Priority** — `P0` (urgent) / `P1` (normal) / `P2` (someday).
* **Area** — `renderer` / `adapters` (gt, rtables/tern) / `pagination` /
  `borders` / `docs` / `infra-ci`.
* **Agent** — `claude` / `codex` / `human`.  This mirrors the planned
  `exec:agent-<name>` split so multi-agent dispatch and the board stay in
  sync.

**Built-in automation** (Project *Workflows* tab — no code):

* *Item added to project* → set **Status = Backlog**.
* *Issue/PR opened* (auto-add) → added to the board.
* *Pull request opened* → **Status = In review**.
* *Issue or PR closed* → **Status = Done**.

### One-time setup (maintainer)

Creating the board needs the `project` scope, which the default `gh` login
does not carry.  A maintainer runs this **once**:

```bash
gh auth refresh -s project,read:project          # grant the scope

# create the board and capture its number
gh project create --owner ichirio --title "rtfreporter roadmap"

# add the custom single-select fields (repeat --single-select-option per value)
gh project field-create <N> --owner ichirio --name Priority \
  --data-type SINGLE_SELECT --single-select-options P0,P1,P2
gh project field-create <N> --owner ichirio --name Area \
  --data-type SINGLE_SELECT \
  --single-select-options renderer,adapters,pagination,borders,docs,infra-ci
gh project field-create <N> --owner ichirio --name Agent \
  --data-type SINGLE_SELECT --single-select-options claude,codex,human
```

Then, in the board's web UI, enable **Workflows** (the four automations
above) and turn on **auto-add** for the `rtfreporter` repository.  Existing
open issues can be bulk-added from the board's *＋ Add items* search.

Until the board exists, labels + milestones already give a usable backlog
view via the Issues tab (filter by `exec:agent`, by milestone, or by type).

## Code style

- **S3 throughout**; the package has zero hard runtime dependencies
  (only `methods`, which ships with R). Optional integrations (gt,
  gtsummary, rtables/tern, ...) live in `Suggests` and must be guarded
  with `requireNamespace(...)`.
- twips are the only internal length unit.
- Keep R source ASCII-only (use `\uXXXX` escapes); non-ASCII is fine in
  comments and roxygen but not in code.
- Two-space indentation, `<-` for assignment, and `snake_case` for
  public functions; internal helpers are prefixed with a dot
  (`.helper_name`).
- **Lint** with [`lintr`](https://lintr.r-lib.org/): run
  `lintr::lint_package()` before opening a PR (the **lint** CI workflow runs
  the same check and must pass). The enforced rule set lives in the
  repository-root `.lintr`. It is intentionally a baseline: several purely
  stylistic linters (line length, indentation, braces, ...) are deferred to a
  future dedicated formatting pass — see the comments in `.lintr` — so adding
  them back is a follow-up, not a blocker today.
- See
  [`AGENTS.md`](https://github.com/ichirio/rtfreporter/blob/main/AGENTS.md)
  for the repository layout and the internal architecture, and
  [`LEARNING.md`](https://github.com/ichirio/rtfreporter/blob/main/LEARNING.md)
  for the design rationale.

## Development setup

```r
install.packages("devtools")
devtools::install_dev_deps()   # installs Suggests used by tests/vignettes
devtools::load_all()           # load the package for interactive work
```

## Versioning & releases

Versions follow `MAJOR.MINOR.PATCH`.  **All of the rules below apply from
v0.1.0 onward.**  (The pre-v0.1.0 `0.0.x` history and its `*-alpha`
releases are throw-away experiments — see *First release* below.)

> **Gotcha:** the `DESCRIPTION` `Version:` field must be **digits and dots
> only** (e.g. `0.1.0`).  A suffix such as `0.1.0-alpha` makes R raise a
> `Malformed package version` error.  Use the suffix-free number in
> `DESCRIPTION`; the `-alpha`/`-rc` style, if ever needed, belongs only on
> the git tag / GitHub Release name.

### What each position means

- **Development version — `vX.Y.Z` (Z ≥ 1).**  The rolling, in-progress
  version that lives on `main` between releases.  Bug fixes, internal
  refactors, documentation, and new work all land here first.  A
  development version is installable **only from GitHub**
  (`remotes::install_github("ichirio/rtfreporter")`); it is **never**
  submitted to CRAN.
- **Minor release — `vX.Y.0` (Y ≥ 1).**  A published release adding
  features that are **backward compatible with the same major version**.
  A minor release may *deprecate* a function (it keeps working and emits a
  deprecation warning) but must **never remove or break** existing public
  behaviour.  Documented in `NEWS.md` and `CHANGELOG.md`, tagged, given a
  GitHub Release, and (once the package is on CRAN) submitted to CRAN.
- **Major release — `vX.0.0`.**  A published release that **may contain
  breaking changes**.  This is the **only** place where functions
  deprecated in earlier minors **may be removed**.  Every breaking change
  is documented under a "Breaking changes" heading in `NEWS.md`.
  - **`v1.0.0` specifically** is cut **only after CRAN registration has
    been achieved** and the public API is considered stable.  At v1.0.0
    the **`lifecycle: experimental` badge is removed** (the package
    graduates to *stable*) and any "the API may change" wording is
    dropped.

### Backward-compatibility contract

- Within one major version, **no minor or patch release breaks user
  code.**
- Deprecation lifecycle: *deprecate in a minor* (function still works +
  warns) → *remove only in the next major*.

### Procedure — routine development bump (`vX.Y.Z`)

**Each pull request raises the development version by exactly one PATCH.**

> **Enforced by CI.**  The `version-guard` workflow fails any PR that raises the
> MINOR or MAJOR position without the `release` label, so an ordinary
> development PR can only bump the PATCH (or leave the version unchanged).  A
> MINOR/MAJOR bump is therefore a deliberate, labelled release action — never an
> accident.

1. As the **last step before you request review**, bump the `DESCRIPTION`
   `Version:` PATCH by one (e.g. `0.1.3` → `0.1.4`).
2. Add a bullet under the `# rtfreporter (development version)` heading in
   `NEWS.md`.
3. Run `devtools::document()`, `devtools::test()`, `devtools::check()`.
4. No git tag, no GitHub Release, no CRAN submission for a development bump.
   (A pure typo / comment fix may skip the bump; when in doubt, bump.)

**Avoiding version collisions across overlapping PRs.**  Because every PR
edits the same `Version:` field, two open PRs can choose the same number.
Keep the version on `main` strictly increasing:

- Bump **as late as possible** — just before review / merge — not when you
  open the branch.
- Before merging, **rebase (or merge `main`) into your branch**.  If `main`'s
  `Version:` is now equal to or ahead of yours, reset yours to *that* version
  **+ 1** and re-run the checks.
- If two PRs still race, the **second one to merge re-bumps** after rebasing;
  a maintainer may also adjust the number at merge time.

### Minor / major bumps are release actions (Collaborators only)

Raising the **MINOR** (`vX.Y.0`) or **MAJOR** (`vX.0.0`) number is *not* part
of an ordinary contribution PR.  It is a release, started from a dedicated
**release Issue** and carried out with the procedures below.  **At present
only repository Collaborators may open a release Issue and perform a
minor/major bump.**  An ordinary PR should never change the MINOR or MAJOR
position.

### Procedure — minor release (`vX.Y.0`)

1. Confirm `main` is green on all CI workflows and `devtools::check()` is
   `0 errors / 0 warnings`.
2. In `NEWS.md`, rename the `(development version)` section to
   `# rtfreporter X.Y.0` and tidy the notes.  Update `CHANGELOG.md`.
3. Set `DESCRIPTION` → `Version: X.Y.0`.
4. Refresh docs (`devtools::document()`), update the README roadmap/badges
   if needed, and confirm the pkgdown site builds.
5. Commit as `release: vX.Y.0`, open a PR, and merge once CI is green.
6. Tag and publish from the merge commit:

   ```bash
   git tag vX.Y.0
   git push origin vX.Y.0
   gh release create vX.Y.0 --title "rtfreporter X.Y.0" \
     --notes-file <notes-from-NEWS> --latest
   ```

7. **(Once on CRAN)** run the CRAN pre-checks and submit —
   `devtools::check_win_devel()`, `urlchecker::url_check()`,
   `devtools::release()`.
8. Open the next development cycle: bump `DESCRIPTION` to the next
   development version (e.g. `X.Y.1`) and add a fresh
   `# rtfreporter (development version)` heading to `NEWS.md`.

### Procedure — major release (`vX.0.0`)

Everything in the minor-release procedure, **plus**:

1. **Remove** functions that were deprecated in earlier minors, and
   describe each removal + its migration path under "Breaking changes" in
   `NEWS.md`.
2. Audit for and document any other breaking change.
3. For **v1.0.0**: confirm CRAN registration is in place, then remove the
   `lifecycle: experimental` badge (set the lifecycle to *stable*) in the
   README and `DESCRIPTION`, and drop any "experimental / API may change"
   wording.

### First release (`v0.1.0`) — one-time cleanup

Follow the minor-release procedure, and additionally **delete the
pre-v0.1.0 `*-alpha` tags and GitHub Releases** so the published history
starts clean at v0.1.0:

```bash
for t in v0.0.1-alpha v0.0.2-alpha v0.0.3-alpha v0.0.4-alpha r-v0.0.1; do
  gh release delete "$t" --yes        2>/dev/null || true   # delete the GitHub Release
  git push origin ":refs/tags/$t"     2>/dev/null || true   # delete the remote tag
  git tag -d "$t"                     2>/dev/null || true   # delete the local tag
done
```

From v0.1.0 onward, use clean `vX.Y.Z` tags only (no `-alpha` suffix, no
`r-` prefix), and mark the newest release `--latest`.

## Code of conduct

This project is released with a [Contributor Code of
Conduct](CODE_OF_CONDUCT.md). By contributing, you agree to abide by its
terms.
