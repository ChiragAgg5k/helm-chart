# Changelog

All notable changes to the Appwrite Helm chart are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and the chart follows [Semantic Versioning](https://semver.org/).
Each release's entries are mirrored into the `artifacthub.io/changes`
annotation in `charts/appwrite/Chart.yaml`.

## [Unreleased]

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
