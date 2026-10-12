# Example values

Values files to copy and adapt. Each starts with a comment saying what it
needs (prerequisites, Secrets and their keys) and how to install it. CI
renders each combination below (`make examples`), so they stay in step with
the chart.

Start from one base file:

| File | Use it for |
| --- | --- |
| [`local.yaml`](local.yaml) | Trying Appwrite on kind, k3d or Rancher Desktop over plain HTTP |
| [`minimal.yaml`](minimal.yaml) | A first install on a real cluster: your domain, HTTPS through cert-manager, built-in datastores |
| [`production.yaml`](production.yaml) | Managed datastores, S3, Secrets you manage, replicas, grouped workers, NetworkPolicies |

Then add overlays:

| File | Adds | Goes on top of |
| --- | --- | --- |
| [`external-services.yaml`](external-services.yaml) | Your own PostgreSQL, Redis, ClickHouse, S3 and SMTP, each block annotated | `minimal.yaml` or `production.yaml` |
| [`aws.yaml`](aws.yaml) | RDS, ElastiCache, S3, SES, EFS and ClickHouse Cloud, with the AWS-side setup | `minimal.yaml` or `production.yaml` |
| [`gcp.yaml`](gcp.yaml) | Cloud SQL, Memorystore, Cloud Storage, Filestore, ClickHouse Cloud and an SMTP provider, with the Google Cloud setup | `minimal.yaml` or `production.yaml` |
| [`azure.yaml`](azure.yaml) | Azure Database for PostgreSQL, Azure Cache for Redis, Azure Files, ClickHouse Cloud and an SMTP provider, with the Azure setup. Files stay on the volume: Azure Blob Storage has no S3 API | `minimal.yaml` or `production.yaml` |
| [`functions.yaml`](functions.yaml) | Functions and Sites: S3 with its keys inline, the executor and wildcard previews | `minimal.yaml` alone |
| [`functions-existing-secrets.yaml`](functions-existing-secrets.yaml) | Functions and Sites where S3 comes from a Secret you manage, so the executor needs Secrets of its own | `production.yaml`, or `minimal.yaml` with `external-services.yaml`, `aws.yaml` or `gcp.yaml` |

There are two Functions files because the executor runs in a namespace of its
own and can't read Secrets in the Appwrite namespace. With S3 keys in your
values, the chart copies them over. With S3 keys in a Secret you manage, it
can't, and you create a Secret for the executor yourself
([executor.md](../docs/executor.md#existing-secrets)).

## Combinations

These are the combinations CI checks:

| Files, in order | What you get |
| --- | --- |
| `local.yaml` | A local install |
| `minimal.yaml` | A first real install |
| `minimal.yaml`, `external-services.yaml` | Your own datastores, S3 and SMTP |
| `minimal.yaml`, `aws.yaml` | AWS services |
| `minimal.yaml`, `gcp.yaml` | Google Cloud services |
| `minimal.yaml`, `azure.yaml` | Azure services, with files on Azure Files |
| `minimal.yaml`, `functions.yaml` | A first real install with Functions and Sites |
| `minimal.yaml`, `external-services.yaml`, `functions-existing-secrets.yaml` | Your own datastores, with Functions and Sites |
| `minimal.yaml`, `aws.yaml`, `functions-existing-secrets.yaml` | AWS services, with Functions and Sites |
| `minimal.yaml`, `gcp.yaml`, `functions-existing-secrets.yaml` | Google Cloud services, with Functions and Sites |
| `production.yaml` | Production |
| `production.yaml`, then one of `external-services.yaml`, `aws.yaml`, `gcp.yaml` or `azure.yaml` | Production with those datastores instead |
| `production.yaml`, `functions-existing-secrets.yaml` | Production with Functions and Sites |

Helm merges files given with `-f` from left to right, so later files win:

```console
helm install appwrite oci://ghcr.io/appwrite/charts/appwrite \
  --namespace appwrite --create-namespace \
  -f minimal.yaml -f external-services.yaml \
  --wait --timeout 15m
```

The merge is key by key, so an overlay keeps every key of the files before
it that it doesn't set. That matters for credentials: over `production.yaml`,
whose database password is under the key `password` (CloudNativePG's), the
overlays set `database.password.secretKey: db-password` again, and `aws.yaml`
sets `redis.password.secretName: ""` so ElastiCache isn't sent the password
from `appwrite-redis`.

## Getting the files

Until the first release is on `ghcr.io`, clone the repository and install
from it, with `./charts/appwrite` in place of the `oci://` reference
([installing from source](../docs/getting-started.md#installing-from-source)):

```console
git clone https://github.com/appwrite/helm-chart
cd helm-chart
helm install appwrite ./charts/appwrite \
  --namespace appwrite --create-namespace \
  -f examples/minimal.yaml --wait --timeout 15m
```

Or download a single file:

```console
curl -fsSLO https://raw.githubusercontent.com/appwrite/helm-chart/main/examples/minimal.yaml
```

Every value is listed in the [chart README](../charts/appwrite/README.md#values),
and `helm show values ./charts/appwrite` (or the `oci://` reference once it's
published) prints the defaults with their comments.
