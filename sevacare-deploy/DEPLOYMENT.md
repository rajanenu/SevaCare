# SevaCare — Cloud Deployment (GCP)

Live demo running on GCP project **`sevacareapp`** (region **`asia-south1`**, Mumbai).
Secrets live in **Secret Manager** and in the gitignored local **`.env.production`** (never committed).

## Live URLs
| Service | URL |
|---|---|
| Frontend (Flutter web) | https://sevacare-frontend-2glz4tgi3q-el.a.run.app |
| Backend (Spring Boot API) | https://sevacare-backend-2glz4tgi3q-el.a.run.app |
| Backend health | …/actuator/health |

## Architecture
- **Cloud Run** `sevacare-backend` — always-warm (min=1, max=20 — see "Scaling" below), 1 vCPU / 1 GiB, profile `production`, connects to Cloud SQL via the built-in socket + `postgres-socket-factory`. Secrets from Secret Manager: `SEVACARE_DB_URL`, `SEVACARE_DB_USERNAME`, `SEVACARE_DB_PASSWORD`, `SEVACARE_AUTH_SECRET`. CORS locked to the frontend origin via `SEVACARE_CORS_ORIGINS`.
- **Cloud Run** `sevacare-frontend` — scale-to-zero (min=0, max=2), 256 MiB, nginx serving Flutter web built with `API_BASE_URL=<backend>/api/v1`.
- **Cloud SQL** `sevacare-db` — PostgreSQL 16, **db-g1-small**, Enterprise edition, single zone (no HA), 10 GB SSD. Single tenant: **T-1013 "Lakshmi Kishore"**.
- **Artifact Registry** `asia-south1-docker.pkg.dev/sevacareapp/sevacare/{backend,frontend}`.

## Cost (after the free trial)
Main recurring cost is Cloud SQL db-g1-small (~$25/mo). Frontend scales to zero (~$0 idle).
Backend is always-warm (small always-on charge). **Stop the SQL instance between demos** to cut cost to near-zero:
```
gcloud sql instances patch sevacare-db --activation-policy=NEVER   # stop
gcloud sql instances patch sevacare-db --activation-policy=ALWAYS  # start
```

## Prerequisites (local, one-time)
```bash
export CLOUDSDK_PYTHON=/opt/homebrew/bin/python3.11   # SDK's bundled Py3.9 is unsupported
gcloud auth login          # account: sigineni123@gmail.com (owns sevacareapp)
gcloud config set project sevacareapp
```

## Build speed
Both cloud builds run on `E2_HIGHCPU_8` workers (set in the cb-*.yaml files) and the
frontend pulls its Flutter SDK + nginx base images from our own Artifact Registry
mirror (in-region) instead of ghcr.io/Docker Hub. After upgrading the Flutter SDK
version in `Dockerfile.frontend`, refresh the mirror once:
```bash
gcloud builds submit --no-source --config=sevacare-deploy/cb-mirror-base-images.yaml
```
Backend and frontend submits are independent — run them in parallel (two terminals
or `&`) when both changed.

## Redeploy backend (after code change)
```bash
source .env.production
IMG=asia-south1-docker.pkg.dev/sevacareapp/sevacare/backend
gcloud builds submit --config=sevacare-deploy/cb-backend.yaml .   # or the scratch config
gcloud run deploy sevacare-backend --image=$IMG:latest --region=asia-south1 \
  --min-instances=1 --max-instances=20
```

## Scaling & the connection-pool ceiling

The number that can take the platform down is **instances × pool size vs the
Cloud SQL connection limit**. Each backend instance opens up to
`SEVACARE_DB_POOL_MAX` (default **5**) connections; db-g1-small allows ~200.
Unbounded Cloud Run autoscaling would sail past that and turn a traffic spike
into connection-refused errors — a hard outage, not a slowdown. Hence:

- `--max-instances=20` → worst case 100 connections, safely under the ceiling.
  Requests queue briefly at the limit; a queue is survivable, exhaustion is not.
  **20, not 30**: the project's `CpuAllocPerProjectRegion` quota in
  `asia-south1` is 20 vCPU total (1 vCPU/instance here), and `gcloud run
  deploy` refuses a `--max-instances` that could exceed it. Request a quota
  increase before raising this further.
- `--min-instances=1` → no 10–20 s Spring Boot cold start for the unlucky first
  request. (Virtual threads are on, so per-instance concurrency is limited by
  the DB pool, not by threads.)
- Before real load: size the DB up (e.g. `db-custom-2-7680`, ~800 connections),
  **then** raise `SEVACARE_DB_POOL_MAX` and `--max-instances` together (and
  the CPU quota if still capped), keeping the product under the new limit.

## Redeploy frontend (after UI change or backend URL change)
```bash
gcloud builds submit --config=sevacare-deploy/cb-frontend.yaml .  # bakes API_BASE_URL
gcloud run deploy sevacare-frontend --image=asia-south1-docker.pkg.dev/sevacareapp/sevacare/frontend:latest --region=asia-south1
```

## Android release signing

Release builds are signed with a real upload key, not the debug key. The
keystore lives **outside the repo** at `~/sevacare-keys/upload-keystore.jks`
(so neither git nor `gcloud builds submit`, which uploads the working tree,
can ever ship it); `sevacare-flutter/android/key.properties` (git-ignored)
holds the passwords and points at it. On a machine without `key.properties`
the build silently falls back to debug signing — fine for testing, not
shippable.

**Back the keystore + key.properties up somewhere safe.** Losing them means
losing the ability to update the app on the Play Store. When enrolling in
Play App Signing, this key becomes the *upload* key and Google holds the app
signing key — that is the recommended path.

## Direct DB access (Cloud SQL Auth Proxy)
```bash
cloud-sql-proxy --port 5433 --token "$(gcloud auth print-access-token)" sevacareapp:asia-south1:sevacare-db &
PGPASSWORD=<SEVACARE_DB_PASSWORD from .env.production> psql -h 127.0.0.1 -p 5433 -U sevacare_app -d seva_care
```

## Teardown (stop all billing)
```bash
gcloud run services delete sevacare-backend sevacare-frontend --region=asia-south1
gcloud sql instances delete sevacare-db
```
