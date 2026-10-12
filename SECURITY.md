# Security policy

## Reporting a vulnerability

Report vulnerabilities in this chart privately through
[GitHub security advisories](https://github.com/appwrite/helm-chart/security/advisories/new).
Please don't open a public issue.

Include the chart version, the values you used (with secrets removed), and
steps to reproduce. You should get a reply within a week.

This covers what the chart deploys and how: its templates and defaults,
generated credentials, NetworkPolicies, Pod Security settings, and the
release pipeline. Vulnerabilities in Appwrite itself belong upstream; see
<https://github.com/appwrite/appwrite/security/policy>. Report problems in
the other images the chart runs (Open Runtimes, PostgreSQL, Redis,
ClickHouse) to their projects, unless the chart's configuration of them is
the cause.

## Supported versions

Only the latest chart release receives fixes.

## Verifying releases

Every release is signed with cosign and has a build provenance attestation;
[docs/security.md](docs/security.md#verifying-chart-signatures) shows how to
check both before installing.
