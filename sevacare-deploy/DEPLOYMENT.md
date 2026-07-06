# SevaCare — Cloud Deployment (GCP)

Live demo running on GCP project **`sevacareapp`** (region **`asia-south1`**, Mumbai).
Secrets live in **Secret Manager** and in the gitignored local **`.env.production`** (never committed).

## Live URLs
| Service | URL |
|---|---|
| Frontend (Flutter web) | https://sevacare-frontend-209136271820.asia-south1.run.app |
| Backend (Spring Boot API) | https://sevacare-backend-209136271820.asia-south1.run.app |
| Backend health | …/actuator/health |

## Architecture
- **Cloud Run** `sevacare-backend` — always-warm (min=1, max=1), 1 vCPU / 1 GiB, profile `production`, connects to Cloud SQL via the built-in socket + `postgres-socket-factory`. Secrets from Secret Manager: `SEVACARE_DB_URL`, `SEVACARE_DB_USERNAME`, `SEVACARE_DB_PASSWORD`, `SEVACARE_AUTH_SECRET`. CORS locked to the frontend origin via `SEVACARE_CORS_ORIGINS`.
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

## Redeploy backend (after code change)
```bash
source .env.production
IMG=asia-south1-docker.pkg.dev/sevacareapp/sevacare/backend
gcloud builds submit --config=sevacare-deploy/cb-backend.yaml .   # or the scratch config
gcloud run deploy sevacare-backend --image=$IMG:latest --region=asia-south1
```

## Redeploy frontend (after UI change or backend URL change)
```bash
gcloud builds submit --config=sevacare-deploy/cb-frontend.yaml .  # bakes API_BASE_URL
gcloud run deploy sevacare-frontend --image=asia-south1-docker.pkg.dev/sevacareapp/sevacare/frontend:latest --region=asia-south1
```

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
