# Getting started

This guide takes you from nothing to a working Appwrite console. Pick the
path that fits:

- [**Try it on your machine**](#try-it-on-your-machine): a local cluster,
  plain HTTP, about ten minutes.
- [**Install on a real cluster**](#install-on-a-real-cluster): your own
  domain, HTTPS through cert-manager.

Both use the chart's built-in PostgreSQL, Redis and ClickHouse; you can
[switch to your own](external-databases.md) at any point. Functions and
Sites need extra infrastructure and come [afterwards](#functions-and-sites).

> [!NOTE]
> Until the first release is on `ghcr.io`, the
> `oci://ghcr.io/appwrite/charts/appwrite` commands below fail because the
> chart isn't there yet. Clone the repository and use `./charts/appwrite`
> instead ([installing from source](#installing-from-source)).

## What you need

- Kubernetes 1.29 or later, with a default StorageClass
- [Helm](https://helm.sh/docs/intro/install/) 4, or Helm 3.18 or later
- `kubectl` pointed at the cluster
- About 2 CPUs and 4 GiB of memory free for Appwrite

Appwrite's console and API share one hostname: requests to `/v1` go to the
API, everything else to the console. Something has to split that traffic,
which is why both paths use an ingress controller. A plain
`kubectl port-forward` to the console isn't enough, because the console
would send its API calls to itself.

## Try it on your machine

This uses [kind](https://kind.sigs.k8s.io), which runs the cluster in Docker,
and Traefik. Any local cluster works; k3d, k3s and Rancher Desktop already
include Traefik, so skip step 2 there.

**1. Create a cluster.**

```console
kind create cluster --name appwrite
```

**2. Install an ingress controller.**

```console
helm install traefik traefik --repo https://traefik.github.io/charts \
  --namespace traefik --create-namespace \
  --set service.type=ClusterIP --wait
```

**3. Install Appwrite.**

```console
helm install appwrite oci://ghcr.io/appwrite/charts/appwrite \
  --namespace appwrite --create-namespace \
  --set appwrite.domain=appwrite.localhost \
  --set appwrite.certificatesEmail=you@example.com \
  --set appwrite.forceHttps=false \
  --set ingress.enabled=true \
  --wait --timeout 15m
```

These are the settings in [`examples/local.yaml`](../examples/local.yaml).
`forceHttps=false` is needed because nothing terminates TLS locally. The
first start pulls about 2 GB of images and creates the database schema, so
expect a few minutes. From a clone, use `./charts/appwrite` in place of the
`oci://` reference ([installing from source](#installing-from-source)).

**4. Open it.**

```console
kubectl -n traefik port-forward svc/traefik 80:80
```

Browse to <http://appwrite.localhost>. Chrome and Firefox resolve any
`*.localhost` name to your own machine, so no DNS setup is needed. If your
browser or SDK doesn't, add `127.0.0.1 appwrite.localhost` to your hosts
file (`/etc/hosts`).

Sign up: the first account becomes the console's administrator, and nobody
else can sign up without an invitation from it. Create a project, and point
an SDK at `http://appwrite.localhost/v1`.

Forward port 80 rather than another one: Appwrite writes `appwrite.domain`
without a port into the links it generates (emails, OAuth redirects,
previews). With another port the console works, but those links don't.
macOS and Windows let you bind port 80; on Linux it usually needs `sudo`,
which then needs your kubeconfig passed explicitly:

```console
sudo kubectl --kubeconfig "${KUBECONFIG:-$HOME/.kube/config}" \
  -n traefik port-forward svc/traefik 80:80
```

Functions and Sites work locally too once you add S3 storage and
`compute.enabled` ([below](#functions-and-sites)), with two limits: previews
at `*.functions.appwrite.localhost` open in Chrome and Firefox, which resolve
`*.localhost` themselves, but not in every browser; and function code can't
call Appwrite back at `appwrite.localhost`, which inside a runtime is the
runtime itself. For that, give the install a domain that resolves to your
ingress controller from inside the cluster too.

**Clean up** when you're done:

```console
kind delete cluster --name appwrite
```

## Install on a real cluster

### Before you start

- **An ingress controller** with an IngressClass, or a Gateway API
  implementation ([networking.md](networking.md#gateway-api)).
- **[cert-manager](https://cert-manager.io)** with a `ClusterIssuer` for
  Let's Encrypt, here called `letsencrypt`. HTTP-01 is enough for the main
  domain.
- **A DNS record** for your domain, for example `appwrite.example.com`,
  pointing at the ingress controller's load balancer.

### Decide before the first install

These are hard to change once Appwrite holds data:

| Decide | Why it's hard to change later | Read |
| --- | --- | --- |
| **Release name**, or `fullnameOverride` | Every resource name starts with it, including the Secret and the volumes. A new name is a new install, with new credentials and empty volumes. | [Conventions](README.md#conventions) |
| **The encryption key** | The chart generates `_APP_OPENSSL_KEY_V1` once. Without it, a database backup can't be read. Back it up after installing ([step 5](#5-back-up-the-encryption-key)), or create it yourself and pass `appwrite.secrets.existingSecret`. | [Bringing your own Secrets](security.md#bringing-your-own-secrets) |
| **`appwrite.domain`** | It ends up in OAuth redirect URLs you register with providers, Git webhooks, the CNAME target of custom domains, and the function and site preview domains stored in the database. Changing it breaks all of them. | [Custom domains](networking.md#custom-domains) |
| **Database engine** | PostgreSQL, built-in or external, is recommended and the one CI tests. Moving to another engine later is a data migration, not a values change. | [External databases](external-databases.md) |
| **Storage device** | `storage.device` is `local` (the `/storage` volume) or `s3`. Files stay where they were written, so switching later leaves them behind. Functions and Sites need `s3`. | [Storage](storage.md) |
| **`/storage` access mode** | ReadWriteOnce keeps every pod that mounts `/storage` on one node; ReadWriteMany lets them spread. A claim's access mode can't be changed, only replaced with a new claim. | [ReadWriteOnce vs ReadWriteMany](storage.md#readwriteonce-vs-readwritemany) |

### 1. Write a values file

Start from [`examples/minimal.yaml`](../examples/minimal.yaml), or write it
yourself:

```yaml
# values.yaml
appwrite:
  domain: appwrite.example.com
  certificatesEmail: ops@example.com    # Let's Encrypt account for custom domains

ingress:
  enabled: true
  className: traefik                    # your IngressClass
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt
  tls:
    enabled: true                       # certificate in Secret appwrite-tls
  wildcard:
    enabled: false                      # function and site previews; see "Functions and Sites"
```

`appwrite.forceHttps` is on by default: Appwrite redirects HTTP to HTTPS and
generates `https://` links. Keep `ingress.tls.enabled` on with it, otherwise
the redirect points at an HTTPS endpoint nothing serves.

To send emails (verification, password recovery, invitations), add SMTP.
[Integrations](integrations.md#email-smtp) lists the settings for SES,
SendGrid, Postmark, Mailgun and others.

```yaml
smtp:
  host: smtp.example.com
  port: 587
  username: appwrite
  password:
    value: <password>                   # or secretName: <Secret with key smtp-password>
appwrite:
  system:
    emailAddress: appwrite@example.com
```

To use managed PostgreSQL, Redis, ClickHouse or S3 from the start, add
[`examples/external-services.yaml`](../examples/external-services.yaml),
[`aws.yaml`](../examples/aws.yaml), [`gcp.yaml`](../examples/gcp.yaml) or
[`azure.yaml`](../examples/azure.yaml) as a second `-f` file. Each starts
with the Secret it needs; [external-databases.md](external-databases.md)
explains every block.

### 2. Install

```console
helm install appwrite oci://ghcr.io/appwrite/charts/appwrite \
  --namespace appwrite --create-namespace \
  -f values.yaml --wait --timeout 15m
```

From a clone, use `./charts/appwrite` in place of the `oci://` reference
([installing from source](#installing-from-source)). The chart checks its
values first and stops with a message naming anything that's missing or
inconsistent.

### 3. Check it

```console
kubectl -n appwrite get pods
helm test appwrite -n appwrite
kubectl -n appwrite get certificate
```

Every pod should be `Running`, the three tests should pass, and the
certificate should become `Ready` within a minute or two.

### 4. Sign up

Open `https://appwrite.example.com` and create your account. The first
account becomes the console administrator; others need an invitation
(`appwrite.console.whitelistRoot`).

### 5. Back up the encryption key

The chart generated `_APP_OPENSSL_KEY_V1`, which encrypts data at rest.
Without it, a database backup can't be read. Store it somewhere outside the
cluster now:

```console
kubectl -n appwrite get secret appwrite -o jsonpath='{.data._APP_OPENSSL_KEY_V1}' | base64 -d
```

## Functions and Sites

Functions and Sites are off by default. They need:

- **S3 storage.** Builds and the executor exchange code and build output
  through a bucket ([storage.md](storage.md#s3)).
- **A privileged pod.** Builds run as ordinary Kubernetes Jobs, but
  executions run on the open-runtimes executor, which starts runtime
  containers through a Docker daemon of its own. That daemon is privileged,
  root on its node: you accept it with `compute.executor.privileged` and give
  it nodes of its own.
- **Wildcard DNS and certificates** for previews, at `*.functions.<domain>`
  and `*.sites.<domain>`.

[executor.md](executor.md) walks through all of it. Two example files have
it ready; add one to your install with another `-f`:

| Your other values | Add |
| --- | --- |
| `minimal.yaml`, or your own file without S3 | [`examples/functions.yaml`](../examples/functions.yaml): S3 with the keys inline, and everything else generated by the chart |
| S3 keys in a Secret you manage: `production.yaml`, `external-services.yaml`, `aws.yaml`, `gcp.yaml` | [`examples/functions-existing-secrets.yaml`](../examples/functions-existing-secrets.yaml): the Secrets the executor needs in its own namespace, which you create first |

```console
helm upgrade --install appwrite oci://ghcr.io/appwrite/charts/appwrite \
  --namespace appwrite --create-namespace \
  -f values.yaml -f functions.yaml --wait --timeout 15m
```

Each file's header lists what to set up first, including nodes for the
executor, labelled and tainted `workload=executor`. Without them, the
executor pod stays `Pending`.

Both files turn `ingress.wildcard.enabled` back on for previews. That needs
DNS records for `*.functions.appwrite.example.com` and
`*.sites.appwrite.example.com` pointing at the ingress controller, and a
wildcard certificate, which only a DNS-01 issuer can get.
`ingress.annotations` applies to every Ingress, so the files give the
wildcard Ingress its own issuer; otherwise cert-manager tries HTTP-01, which
can't issue wildcards:

```yaml
ingress:
  wildcard:
    enabled: true
    annotations:
      cert-manager.io/cluster-issuer: letsencrypt-dns01   # a DNS-01 ClusterIssuer
    tls:
      enabled: true
```

[networking.md](networking.md#cert-manager) has the details.

## Installing from source

Until the chart is published, or to test a branch, install from a clone. The
commands are the same with `./charts/appwrite` in place of the `oci://`
reference:

```console
git clone https://github.com/appwrite/helm-chart
cd helm-chart
```

On your machine, with the settings of [step 3](#try-it-on-your-machine):

```console
helm install appwrite ./charts/appwrite \
  --namespace appwrite --create-namespace \
  -f examples/local.yaml --wait --timeout 15m
```

On a real cluster, with [your values file](#1-write-a-values-file):

```console
helm install appwrite ./charts/appwrite \
  --namespace appwrite --create-namespace \
  -f values.yaml --wait --timeout 15m
```

To try a branch, `git checkout` it first. `helm upgrade` takes
`./charts/appwrite` the same way; `helm test` and `helm uninstall` only need
the release name.

## Next steps

- [Production checklist](production.md): what to change before real users
  depend on it, such as managed databases, S3, replicas and backups.
- [External databases](external-databases.md) and [storage](storage.md#s3):
  moving PostgreSQL, Redis, ClickHouse and files to managed services.
- [Integrations](integrations.md): email, deploying from GitHub, SMS and
  error tracking.
- [Example values](../examples/README.md): base files and overlays, and the
  combinations that work together.
- [Configuration](../charts/appwrite/README.md#values): every value.
  Appwrite settings without a dedicated value go in `appwrite.config`.
- [Upgrading](upgrading.md) and [backup and restore](backup-restore.md).
- [Troubleshooting](troubleshooting.md).

## Uninstalling

```console
helm uninstall appwrite -n appwrite
```

Helm leaves the data behind on purpose: the Secret with the encryption key
and passwords, and the PersistentVolumeClaims of `/storage` and the
datastores. Installing again with the same release name picks them up.
To remove everything:

```console
kubectl -n appwrite delete secret appwrite
kubectl -n appwrite delete pvc -l app.kubernetes.io/instance=appwrite
```

Delete the Secret and the claims together. A new Secret with an old database
means new passwords for a database that still expects the old ones.

With Functions and Sites, `helm uninstall` also deletes the build and
executor namespaces the chart created, with any builds and runtimes still in
them. Namespaces you created yourself, and the Secrets in them, stay.
