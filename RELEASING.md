# Releasing

## Versions and the changelog

Pull requests don't bump the chart version. Each one that changes what users
get adds an entry under `## [Unreleased]` in `CHANGELOG.md`; the Changelog
check fails a pull request that changes `charts/appwrite/` without touching
`CHANGELOG.md`, unless it carries the `skip-changelog` label (for changes
users won't notice, such as tests or comments). The version in `Chart.yaml`
changes only in the pull request that cuts a release, so `ct.yaml` keeps
`check-version-increment: false`.

The `artifacthub.io/changes` annotation in `Chart.yaml` is generated from the
`CHANGELOG.md` section of the chart version by `make changes`
([`hack/changelog-changes.sh`](hack/changelog-changes.sh)): one entry per
top-level bullet, its kind from the heading above it (Added, Changed,
Deprecated, Removed, Fixed, Security), links listed with the entry.
`make check-changes`, run by CI, fails when the annotation and the changelog
differ. While `CHANGELOG.md` has no section for the version in `Chart.yaml`
(before the first release, the entries are all under `[Unreleased]`) it has
nothing to compare and passes.

## What the release workflow does

Releases are automated. Every push to `main` that changes
`charts/appwrite/Chart.yaml` runs [`release.yaml`](.github/workflows/release.yaml),
which only acts on `main` and skips itself while the repository is private.
For the `version` in `Chart.yaml` it:

1. stops if `CHANGELOG.md` has no entries under `## [<version>]`, before
   anything is published;
2. packages the chart and pushes it to `oci://ghcr.io/appwrite/charts/appwrite`,
   if the registry answers that the version doesn't exist (any answer other
   than "not found" fails the run instead of pushing again);
3. signs it with cosign (keyless, GitHub OIDC) unless a signature from the
   release workflow is there already, then runs `cosign verify` with the
   identity [docs/security.md](docs/security.md#verifying-chart-signatures)
   gives users;
4. attaches a build provenance attestation unless one verifies already, then
   runs `gh attestation verify`;
5. creates the GitHub release `appwrite-<version>` at the released commit,
   with the chart archive pulled back from the registry and the changelog
   section as notes, unless it exists;
6. pushes `artifacthub-repo.yml` for Artifact Hub.

Every step checks before it acts, so the workflow is safe to re-run, and
merging other changes to `Chart.yaml` only re-checks the current release. The
workflow doesn't run tests: the pull request checks are the gate.

## Cutting a release

1. In `CHANGELOG.md`, rename `## [Unreleased]` to `## [<version>] - <date>`
   and add a new, empty `## [Unreleased]` above it.
2. Bump `version` in `charts/appwrite/Chart.yaml` (SemVer): the patch
   version for fixes, the minor version for new features or a new Appwrite
   minor, the major version for breaking value changes after 1.0. If the
   release has `### Security` entries, set
   `artifacthub.io/containsSecurityUpdates: "true"` (and back to `"false"`
   in the next release).
3. Run `make changes generate test`. `make changes` writes the new section
   into `artifacthub.io/changes`; review the result, and reword the
   changelog rather than the annotation if an entry reads badly.
4. Open a pull request, merge it once the checks pass, and watch the Release
   workflow run on `main`. Then verify the published chart (with cosign 3 or
   later):

   ```console
   helm show chart oci://ghcr.io/appwrite/charts/appwrite --version <version>
   cosign verify ghcr.io/appwrite/charts/appwrite:<version> \
     --certificate-identity https://github.com/appwrite/helm-chart/.github/workflows/release.yaml@refs/heads/main \
     --certificate-oidc-issuer https://token.actions.githubusercontent.com
   gh attestation verify oci://ghcr.io/appwrite/charts/appwrite:<version> --repo appwrite/helm-chart
   ```

## If the workflow fails

Fix the cause and re-run it (Actions → Release → Re-run, or Run workflow on
`main`). A version that is already in the registry isn't pushed again: the
run picks up its digest and adds whatever is missing (signature,
attestation, GitHub release, Artifact Hub metadata). Only delete a version
from the `charts/appwrite` package in GHCR if the published chart itself is
wrong, and then bump the version instead of re-using it where you can:
people may have pulled it already.

## Pre-releases

The workflow marks a version with a `-suffix`, such as `1.1.0-rc.1`, as a
pre-release on GitHub. Set `artifacthub.io/prerelease: "true"` in `Chart.yaml`
for that version only, and back to `"false"` in the next release.

## Before the first release (1.0.0)

The release pull request sets `Chart.yaml` to `1.0.0` and has the changelog
section, so the first release only needs the repository settings:

- [ ] Make the repository public before merging the release pull request:
      the release workflow skips itself while the repository is private. If
      the pull request was merged first, run it manually (Actions → Release
      → Run workflow, on `main`). Build provenance attestations on private
      repositories need GitHub Enterprise Cloud, and keyless signatures record
      the repository in the public Rekor transparency log anyway.
- [ ] After the first push, make the `charts/appwrite` package public in the
      GHCR package settings, and link it to this repository.
- [ ] Turn on private vulnerability reporting (Settings → Code security), so
      the advisory link in [SECURITY.md](SECURITY.md) works.
- [ ] Register the repository on Artifact Hub (kind: Helm charts, URL
      `oci://ghcr.io/appwrite/charts/appwrite`), then add its
      `repositoryID` and an owner to `artifacthub-repo.yml`.
- [ ] Create the `skip-changelog` label.
- [ ] Enable the Renovate GitHub app for the repository, and set up the
      GitHub App that commits `make generate` results to its pull requests
      (see [CONTRIBUTING.md](CONTRIBUTING.md#renovate-pull-requests)).
- [ ] In the branch protection rules for `main`, require the checks of the
      Lint and test workflow, including `Changelog`. The Install and Workflow
      lint workflows only run when their paths change, and GitHub leaves a
      required check of a workflow that didn't run pending, so don't require
      them while they have path filters; `Install result` is the one check
      that sums up every install scenario.
