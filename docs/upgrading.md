# Upgrading

## Chart and Appwrite versions

Each chart version deploys one Appwrite version, its `appVersion`. Upgrading
the chart upgrades Appwrite. You can pin a different Appwrite version with
`image.tag`, but the chart is built and tested for its `appVersion`.

| Chart | Appwrite |
| --- | --- |
| 0.1.0 | 2.3.0 |

The [changelog](../CHANGELOG.md) lists what changed in each chart version,
and [version notes](#version-notes) what you have to do about it.

What CI tests: a fresh install of the `appVersion`, and an upgrade from the
previous Appwrite release (2.2.0, installed with this chart through
`image.tag`) to the `appVersion`, including the data migration. Upgrades from
an earlier chart version aren't tested yet.

## What happens during an upgrade

1. Helm applies the new manifests. Deployments roll out their new pods. The
   scheduler, maintenance and interval tasks, and the worker that consumes
   the `databases` queue, are stopped and then recreated, so there's never
   more than one of each.
2. New API pods create any new tables and collections when they start.
3. If the Appwrite version changed, a post-upgrade hook Job (`appwrite-migrate`)
   runs `php app/cli.php migrate`, which migrates every project's data to the
   new version. Helm waits for hook Jobs, with or without `--wait`, so the
   upgrade only reports success once the migration has finished.

The chart records the running Appwrite version in the `appwrite/version`
annotation of the API Deployment, so upgrades that don't change the version
skip the migration. The exception is a migration that didn't finish: see
[below](#if-the-migration-fails).

**Pass `--wait`.** The migration Job starts with an init container
(`wait-for-api`) that waits until the API answers, but an old API pod
answering counts too. With `--wait`, Helm waits for the new pods to be ready
before it runs post-upgrade hooks, so the migration runs against the new
version, as it does in Appwrite's Docker upgrade. Without it, Helm starts
the Job as soon as the manifests are applied.

## Before you upgrade

1. **Back up.** Appwrite migrations can't be rolled back. Back up the
   database and the chart's Secret; see [backup-restore.md](backup-restore.md).
2. **Read the [version notes](#version-notes)** of every chart version in
   between, and change your values as they say.
3. **Read the Appwrite release notes** for the versions in between, especially
   for breaking API changes your apps depend on.
4. **Don't skip a data migration.** `migrate` applies only the migration of
   the version it runs and doesn't replay those of the versions in between.
   Several releases share a migration: every version from 1.9.6 to 2.3.0
   uses the same one, so 2.0 → 2.3 is a single step. 1.8 → 2.3 isn't: go to
   a release from 1.9.0 to 1.9.5 first, whose migration 2.3 doesn't repeat.
   The table is in Appwrite's
   [`src/Appwrite/Migration/Migration.php`](https://github.com/appwrite/appwrite/blob/2.3.0/src/Appwrite/Migration/Migration.php).

```console
helm upgrade appwrite oci://ghcr.io/appwrite/charts/appwrite \
  --version <new chart version> -n appwrite -f values.yaml --wait --timeout 30m
```

`--timeout` applies to the rollout and, separately, to the migration Job. It
defaults to 5 minutes, too short for most migrations, and large installs can
take much longer. Raise `--timeout` and `migrations.activeDeadlineSeconds`
(default 7200, two hours) together. When `--timeout` runs out first, Helm
reports a failure while the Job keeps running; see
[below](#if-the-migration-fails).

## If the migration fails

The upgrade fails and the Job is kept, so you can read why:

```console
kubectl -n appwrite logs job/appwrite-migrate
kubectl -n appwrite logs job/appwrite-migrate -c wait-for-api   # if it never started
```

The new Appwrite version is already running at that point. Fix the cause,
then either run `helm upgrade` again or run the migration by hand:

```console
kubectl -n appwrite exec deploy/appwrite-api -- php app/cli.php migrate
```

On the next `helm upgrade`, the chart finds the leftover hook Job and runs
the migration again, even though the API Deployment already carries the new
version. Once the migration succeeds, Helm deletes the Job. This relies on
`lookup`, so it only works where Helm talks to the cluster (the Helm CLI,
Flux), not with `helm template` or Argo CD.

If Helm only timed out, the Job is still running. Wait for it before you run
`helm upgrade` again, which would delete it and start over:

```console
kubectl -n appwrite wait --for=condition=complete job/appwrite-migrate --timeout=2h
```

Helm doesn't delete a Job that finished after it stopped waiting, so the next
upgrade runs the migration once more. That's safe, because the migration is
idempotent. To skip it, delete the Job once it has completed:
`kubectl -n appwrite delete job appwrite-migrate`. Do the same after running
the migration by hand.

## Rolling back

`helm rollback` restores the previous manifests, **not the data**. After a
migration ran, the previous Appwrite version may not understand the migrated
data. To go back to an older Appwrite version, restore the backup you took
before upgrading.

`helm upgrade` refuses to deploy an older Appwrite version than the one
running:

```text
Appwrite 2.3.0 is installed and this would downgrade it to 2.2.0. Appwrite can't migrate data backwards; restore a backup taken before the upgrade instead, or set migrations.allowDowngrade=true.
```

The check reads the running version with `lookup`, so it does nothing with
`helm template` or Argo CD. `helm rollback` doesn't check either: it
reapplies stored manifests without rendering the chart.

For the same reason, don't pass `--rollback-on-failure` (`--atomic` in
Helm 3) to an upgrade that changes the Appwrite version: a failed migration
would put the old version back on partly migrated data. Rolling back chart
changes that keep the Appwrite version is safe.

## GitOps

Argo CD doesn't run Helm hooks the way Helm does. Use `migrations.mode: job`:
the chart then renders a regular Job named after the Appwrite version and a
short hash of the Job's spec (`appwrite-migrate-2-3-0-<hash>`). As long as the
spec stays the same, the Job stays the same and the migration runs once.
Changing the version, or the Job's resources, environment or scheduling,
gives a new Job that runs the migration again, which is safe because it's
idempotent. Delete Jobs of older versions whenever you like;
[gitops.md](gitops.md#migrations) has the details.

Argo CD applies the Job together with the new Deployments, so the migration
can start while only old API pods answer. After the sync, check that the API
rollout finished and the Job succeeded:

```console
kubectl -n appwrite rollout status deployment/appwrite-api
kubectl -n appwrite get jobs -l app.kubernetes.io/component=migrate
```

If the Job failed, wait for the rollout to finish, then run the migration by
hand (command below) or delete the Job and let Argo CD's auto-sync create it
again.

Flux runs Helm, so the hook and its retry work as with the Helm CLI. Set the
HelmRelease's `upgrade.timeout` the way you'd set `--timeout`, long enough
for the migration ([gitops.md](gitops.md#flux)).

With `migrations.mode: none`, run the migration yourself after the new version
is up:

```console
kubectl -n appwrite exec deploy/appwrite-api -- php app/cli.php migrate
```

## Helm 3 to Helm 4

Releases installed with Helm 3 keep working with Helm 4. Helm 4 applies
resources with server-side apply only to releases it installs; for releases
created by Helm 3, pass `--server-side=true` once to switch. Don't change
chart-managed resources with `kubectl edit` in between, or the switch reports
field-manager conflicts.

Helm 4 doesn't wait for Deployments unless you pass `--wait`; without it, it
waits only for hooks.

## Version notes

Every chart release that needs something from you gets an entry here, newest
first. Each entry says what changed, what to do, and shows the values before
and after. A release without an entry needs nothing beyond `helm upgrade`.
When you skip versions, apply the entries of every version in between,
oldest first.

### To 0.1.0

The first release. Nothing to do.
