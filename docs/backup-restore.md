# Backup and restore

An Appwrite installation keeps state in five places. Back up the first four,
at the same time if you can. Redis needs no backup.

| What | Where | Why it matters |
| --- | --- | --- |
| Credentials | Secret `appwrite` (or the Secrets you name in `existingSecret` and `secretName`) | `_APP_OPENSSL_KEY_V1` decrypts encrypted data (secrets, OAuth tokens, variables). The built-in PostgreSQL only accepts the password its volume was created with. |
| Database | PostgreSQL (built-in or external) | Users, projects, documents, everything. |
| Files | `/storage` volume, or the S3 bucket | Bucket files, deployments, builds, certificates. |
| ClickHouse | built-in or external | Usage statistics and the history of function and site executions. Losing it loses that history, not your projects' data. |
| Redis | built-in or external | Queues and cache. Jobs in flight are lost, and a restore flushes it anyway. |

The commands below use the release name `appwrite` in namespace `appwrite`:
the built-in datastores' pods are `appwrite-postgresql-0`,
`appwrite-clickhouse-0` and `appwrite-redis-0`.

## Credentials

Back up the chart's Secret once, right after installing, and again after
changing a credential. Keep it somewhere outside the cluster, encrypted:

```console
kubectl -n appwrite get secret appwrite -o yaml > appwrite-secret.yaml
```

The encryption key alone isn't enough to restore the built-in PostgreSQL: a
restored volume still expects the password it was created with. If you bring
your own Secrets (`existingSecret`, `secretName`), back those up, or rely on
the secret manager they come from.

The chart keeps the Secret when you uninstall (`helm.sh/resource-policy: keep`)
and refuses to generate a new encryption key during an upgrade.

## PostgreSQL

Built-in:

```console
kubectl -n appwrite exec appwrite-postgresql-0 -- \
  sh -c 'pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB" --format=custom' > appwrite.dump
```

Restore with Appwrite stopped ([restoring](#restoring), step 1). Drop and
recreate the database first. `pg_restore --clean` isn't enough: it only drops
what's in the dump, and every collection is a table of its own, so tables
created after the backup would stay behind.

```console
kubectl -n appwrite exec appwrite-postgresql-0 -- sh -c \
  'psql -U "$POSTGRES_USER" -d postgres -c "DROP DATABASE \"$POSTGRES_DB\" WITH (FORCE)" -c "CREATE DATABASE \"$POSTGRES_DB\""'
kubectl -n appwrite exec -i appwrite-postgresql-0 -- \
  sh -c 'pg_restore -U "$POSTGRES_USER" -d "$POSTGRES_DB" --exit-on-error' < appwrite.dump
```

For production, prefer continuous backups from your database service or
operator: managed snapshots and point-in-time recovery (RDS, Cloud SQL,
Azure), or CloudNativePG's backups. For an external database, restore through
the provider, or run the same `pg_dump` and `pg_restore` from a machine that
can reach it. Restoring as a user that isn't a superuser needs the extensions
prepared first ([moving from built-in to external](external-databases.md#moving-from-built-in-to-external)).

## Files

- **S3:** enable versioning, and replication to a second bucket or region,
  with your provider. Restoring means restoring objects from those.
- **Volume:** take volume snapshots (`VolumeSnapshot`, with a CSI driver that
  supports them), or use a backup tool such as Velero. The claim is
  `appwrite-storage`.

With S3, the volume still holds the certificates Appwrite issues for custom
domains (`certificates` and `config`), so back it up too if you use custom
domains. Appwrite can issue them again, within Let's Encrypt's rate limits.

## ClickHouse

`BACKUP` writes the `appwrite` database to S3. It refuses to overwrite an
existing backup, so give each one its own path, for example the date:

```console
kubectl -n appwrite exec appwrite-clickhouse-0 -- sh -c \
  "clickhouse-client --user \"\$CLICKHOUSE_USER\" --password \"\$CLICKHOUSE_PASSWORD\" \
    --query \"BACKUP DATABASE appwrite TO S3('https://s3.example.com/backups/clickhouse/2026-10-12', 'KEY', 'SECRET')\""
```

Restore, with Appwrite stopped, by dropping the database and restoring it
from the same path:

```console
kubectl -n appwrite exec appwrite-clickhouse-0 -- sh -c \
  "clickhouse-client --user \"\$CLICKHOUSE_USER\" --password \"\$CLICKHOUSE_PASSWORD\" \
    --query \"DROP DATABASE IF EXISTS appwrite SYNC\""
kubectl -n appwrite exec appwrite-clickhouse-0 -- sh -c \
  "clickhouse-client --user \"\$CLICKHOUSE_USER\" --password \"\$CLICKHOUSE_PASSWORD\" \
    --query \"RESTORE DATABASE appwrite FROM S3('https://s3.example.com/backups/clickhouse/2026-10-12', 'KEY', 'SECRET')\""
```

ClickHouse must be able to reach the S3 endpoint. With
`networkPolicy.egress.enabled`, allow it in `networkPolicy.egress.extraRules`.
For an external ClickHouse, use its own backups (ClickHouse Cloud takes them
automatically).

## Restoring

1. Stop writes: note the current replica counts, then scale the Appwrite
   Deployments to zero. The built-in datastores are StatefulSets and keep
   running.

   ```console
   kubectl -n appwrite get deployment -l app.kubernetes.io/instance=appwrite \
     -o jsonpath='{range .items[*]}{.metadata.name}={.spec.replicas}{"\n"}{end}' > replicas.txt
   kubectl -n appwrite scale deployment -l app.kubernetes.io/instance=appwrite --replicas=0
   ```
2. Restore the database, the files and, if you have a backup, ClickHouse.
3. Make sure the Secret matches the backup: the encryption key, and, if you
   restored the built-in PostgreSQL's volume rather than a dump, its
   password.
4. Flush Redis. Its cache and queued jobs describe the state after the
   backup was taken:

   ```console
   kubectl -n appwrite exec appwrite-redis-0 -- redis-cli FLUSHALL
   ```

   The built-in Redis pod has `REDISCLI_AUTH` set, so no password is needed.
   For an external Redis, flush the database Appwrite uses.
5. Scale the Deployments back to their previous counts:

   ```console
   while IFS== read -r name replicas; do
     kubectl -n appwrite scale deployment "$name" --replicas="$replicas"
   done < replicas.txt
   ```

`kubectl scale` makes kubectl a co-owner of `spec.replicas`. With Helm 4's
server-side apply, a later `helm upgrade` that changes a replica count can
then report a conflict on `spec.replicas`
([gitops.md](gitops.md#server-side-apply)). If it does, run that upgrade with
`--force-conflicts`.

### Into a new cluster

Use the same release name and namespace, and the chart version the backup was
taken with, so Appwrite's version matches the data. Upgrade afterwards.

1. Restore the Secret before installing, so the chart reuses its
   credentials instead of generating new ones. Remove `metadata.uid` and
   `metadata.resourceVersion` from the saved file first; they belong to the
   old object. Helm adopts the Secret on install because it carries the
   release's Helm labels and annotations.

   ```console
   kubectl create namespace appwrite
   kubectl apply -f appwrite-secret.yaml
   ```
2. Install the chart with the API scaled to zero. The other Appwrite pods
   wait for the API, so nothing writes to the empty database. A volume
   restored from a snapshot goes in `storage.volume.existingClaim`.

   ```console
   helm install appwrite oci://ghcr.io/appwrite/charts/appwrite --version <chart version> \
     -n appwrite -f values.yaml --set api.replicaCount=0 --set api.autoscaling.enabled=false
   ```
3. Restore the database, the files and ClickHouse as above. Redis starts
   empty.
4. Start Appwrite:

   ```console
   helm upgrade appwrite oci://ghcr.io/appwrite/charts/appwrite --version <chart version> \
     -n appwrite -f values.yaml --wait
   ```
