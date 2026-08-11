# d3d-claude-gateway

Kubernetes manifests to deploy the [Claude Apps Gateway](https://code.claude.com/docs/en/claude-apps-gateway) on d3d's internal cluster, fronting AWS Bedrock (GovCloud) with Microsoft Entra ID authentication.

## Architecture

- **Gateway** — the `claude` CLI running in `gateway` mode, deployed as a single-replica `Deployment` + `LoadBalancer` `Service` in the `claude-gateway` namespace.
- **Auth** — OIDC against Microsoft Entra ID (US Government cloud), restricted to the `divergent.us` email domain.
- **Model upstream** — AWS Bedrock in `us-gov-west-1`, currently exposing `claude-sonnet-4-5`.
- **Session/usage store** — PostgreSQL, run via CloudNativePG (`cnpg`) as two replicated clusters, `f2` (primary) and `la4`, each archiving WAL to its own S3-compatible object store with a 30-day retention policy.
- **Secrets** — pulled from an Azure Key Vault (GovCloud) via [External Secrets Operator](https://external-secrets.io/), synced hourly into the `claude-gateway-secrets` Kubernetes secret.

## Repository layout

| File | Purpose |
|---|---|
| `Dockerfile` | Builds the gateway image: pins a `claude` CLI version and bakes in `gateway.yaml` |
| `gateway.yaml` | Gateway config template with `@@PLACEHOLDER@@` values, used for building the image |
| `namespace.yaml` | Creates the `claude-gateway` namespace |
| `deployment.yaml` | Gateway `Deployment` + `Service` |
| `gateway-configmap.yaml` | Live gateway config (OIDC, Postgres, Bedrock upstream, models, admin keys) mounted into the pod |
| `externalSecretStore.yaml` | `SecretStore` pointing at the Azure Key Vault (GovCloud) holding gateway secrets |
| `externalSecrets.yaml` | `ExternalSecret` mapping Key Vault entries to the `claude-gateway-secrets` k8s secret |
| `psql/pg-f2.yaml`, `psql/pg-la4.yaml` | CloudNativePG `Cluster` definitions for the two replicated Postgres sites |
| `psql/objectStore-f2.yaml`, `psql/objectStore-la4.yaml` | Barman-cloud `ObjectStore` definitions for WAL/backup storage per site |
| `psql/backup.yaml` | Nightly `ScheduledBackup` for the `la4` cluster |

## Deploying

Apply in dependency order:

```bash
kubectl apply -f namespace.yaml
kubectl apply -f externalSecretStore.yaml
kubectl apply -f externalSecrets.yaml
kubectl apply -f psql/objectStore-f2.yaml -f psql/objectStore-la4.yaml
kubectl apply -f psql/pg-la4.yaml -f psql/pg-f2.yaml
kubectl apply -f psql/backup.yaml
kubectl apply -f gateway-configmap.yaml
kubectl apply -f deployment.yaml
```

The gateway image referenced in `deployment.yaml` (`docker.artifactory.d3d.io/claude-gateway:latest`) must already be built and pushed via the `Dockerfile`, and `regcred` must exist in the namespace as an image pull secret.

## Required secrets (Azure Key Vault)

`externalSecrets.yaml` expects the following keys to exist in the vault referenced by `externalSecretStore.yaml`:

- `OIDC-CLIENT-SECRET`
- `GATEWAY-JWT-SECRET`
- `GATEWAY-ADMIN-READ-KEY`
- `GATEWAY-ADMIN-WRITE-KEY`
- `CLAUDE-PG-USER`
- `CLAUDE-PG-PASSWORD`
- `AWS-ACCESS-KEY-ID`
- `AWS-SECRET-ACCESS-KEY`

## Notes

- `gateway.yaml` is a build-time template (`@@PLACEHOLDER@@` tokens); `gateway-configmap.yaml` is the environment-specific config actually deployed to the cluster.
- Admin write/read keys gate access to the gateway's admin API for usage reporting and spend limits (see `blocked_message` in the config).
