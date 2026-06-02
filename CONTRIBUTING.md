# Contributing to rtfreporter

Thanks for taking the time to contribute! Issues and pull requests are
very welcome at <https://github.com/ichirio/rtfreporter>.

By participating in this project you agree to abide by its
[Code of Conduct](CODE_OF_CONDUCT.md).

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
- **Never commit directly to `main`** (once there is more than one
  contributor).  Enable branch protection on `main`: require a pull
  request, passing CI, and at least one approving review before merge.
- **One topic branch per change**, cut from the latest `main`.  Use a
  short, descriptive name with a type prefix:

  ```
  feature/<slug>     fix/<slug>     docs/<slug>     chore/<slug>
  # or tie it to an issue:  123-read-tfrmt-tables
  ```

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

1. When you land a notable change, bump the **PATCH** number in
   `DESCRIPTION` (e.g. `0.1.0` → `0.1.1`).  Trivial doc-only tweaks need
   not bump.
2. Add a bullet under the `# rtfreporter (development version)` heading in
   `NEWS.md`.
3. `devtools::document()`, `devtools::test()`, `devtools::check()`.
4. No git tag, no GitHub Release, no CRAN submission.

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
