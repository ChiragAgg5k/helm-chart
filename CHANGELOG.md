# Changelog

All notable changes to the Appwrite Helm chart are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and the chart follows [Semantic Versioning](https://semver.org/).
Each release's entries are mirrored into the `artifacthub.io/changes`
annotation in `charts/appwrite/Chart.yaml`.

## [Unreleased]

## [2.0.0] - 2026-10-14

Appwrite 2.5.0, with Functions and Sites on by default. Upgrading from 1.0.0:
see [docs/upgrading.md](docs/upgrading.md#to-200).

### Changed

- Functions and Sites are on by default: `compute.enabled` and
  `compute.executor.privileged` default to `true`, so a plain install runs
  the executor as a privileged pod in a namespace of its own. Set
  `compute.enabled: false` on clusters that forbid privileged pods.
- Files are stored in object storage by default: `storage.device` defaults
  to `s3`, served by the built-in SeaweedFS. To keep 1.0.0's behaviour, set
  `storage.device: local` and `compute.enabled: false`.
- Appwrite 2.5.0, with console 1.2.74, executor 1.1.2, browser 0.3.6 and
  geo 0.3.2, and the new trusted-proxy, internal-address and DNS settings in
  the environment defaults ([networking.md](docs/networking.md#tls-and-forcehttps)).
- External S3 settings move to `storage.s3.external.endpoint` and
  `storage.s3.external.region`, with `storage.s3.mode: external`. Setting
  the old keys fails with where they went.
- ClickHouse drops its per-second metric, trace and text logs and gives
  tables left behind by a config change a TTL, as Appwrite 2.4.0 does.
- CI upgrades from the published chart 1.0.0 with default values.

### Added

- Built-in object storage: SeaweedFS as a single-replica StatefulSet
  (`storage.s3.mode: builtin`), with generated keys, the bucket created on
  start, and a NetworkPolicy that admits only Appwrite, the orchestrator,
  builds and the executor ([storage.md](docs/storage.md#built-in-object-storage)).
- Troubleshooting for deployments that fail with an internal error while
  Functions and Sites are off.

### Removed

- The assistant: Appwrite removed it in 2.4.0. Setting `assistant.*` fails
  with that message.

### Fixed

- Site screenshots: the browser gets the API Service in `ALLOWED_HOSTS`, as
  browser 0.3.5 and later require for private addresses.
- `make env-defaults` works with Appwrite 2.4.0 and later, and no longer
  leaves an error message in `files/env-defaults.yaml` when it fails.

## [1.0.0] - 2026-10-13

First release of the chart, for Appwrite 2.3.0.

### Added

- The API, console, realtime, workers (combined, separate or grouped),
  schedulers, maintenance and interval tasks, and geo, all passing the
  `restricted` Pod Security Standard.
- Built-in single-replica PostgreSQL, Redis and ClickHouse, or external
  services (PostgreSQL, MariaDB, MySQL, MongoDB; Redis; ClickHouse over HTTP
  or TLS). Each backing service (`database`, `redis`, `clickhouse`,
  `storage`, `smtp`, `documentsDb`, `vectorsDb`) has a `mode` switch, and
  every credential takes the same `{value, secretName, secretKey}` shape.
- Storage on a volume or in S3-compatible object storage.
- Opt-in Functions and Sites in the cluster: builds run as Kubernetes Jobs
  through the open-runtimes orchestrator, in their own `baseline` namespace;
  executions run on the open-runtimes executor on Docker-in-Docker, a
  privileged pod you accept with `compute.executor.privileged` (or Sysbox
  through `runtimeClassName`), in its own namespace behind NetworkPolicies.
- Ingress and Gateway API HTTPRoutes for the API, console, realtime,
  function and site previews, and custom domains.
- Optional browser, assistant, autogravity, embedding and MQTT components.
- PodDisruptionBudgets and topology spread by default; opt-in
  NetworkPolicies, HorizontalPodAutoscalers, and metrics for the built-in
  datastores (exporters, ServiceMonitors and a PrometheusRule).
- Credentials generated once and kept across upgrades and uninstalls, with
  guards against changing the encryption key or regenerating datastore
  passwords. Pods restart when a Secret value they read changes.
- Data migrations on upgrade, a downgrade guard, and a guard against an
  `image.tag` of another Appwrite major version.
- The same extension keys on every component, the built-in datastores
  included (`extraEnv`, `extraVolumes`, `extraVolumeMounts`,
  `extraInitContainers`, `extraContainers`), pod-wide `defaults`, and
  `extraObjects` for your own manifests.
- `values.schema.json`, `helm test` pods, documentation from getting started
  to backups, GitOps and troubleshooting, and example values files for local,
  production, external services, AWS, GCP, Azure, and Functions and Sites
  installs.
