# SevaCare – Deployment & Operations

## Project Structure

```
sevacare-deploy/
├── docker-compose.yml      # Full-stack compose (PostgreSQL + Backend + Frontend)
├── docker-compose.prod.yml # Production overrides (env-driven)
├── Dockerfile.backend      # Multi-stage build for Spring Boot backend
├── Dockerfile.frontend     # Multi-stage build for Expo web frontend
├── deploy.sh               # Docker Compose management script
├── start-local.sh          # Local dev startup (no Docker needed)
└── run-tests.sh            # E2E test runner with suite selection
```

## Quick Start

### Local Development (no Docker)

Prerequisites: Java 17+, Node 20+, PostgreSQL 16+ running on port 5432.

```bash
./sevacare-deploy/start-local.sh
```

Or manually:

```bash
# 1. Backend
cd sevacare-backend
./mvnw -pl sevacare-api -am -DskipTests clean package
java -jar sevacare-api/target/*.jar --server.port=8081

# 2. Frontend
cd sevacare-frontend
EXPO_PUBLIC_API_BASE_URL=http://localhost:8081/api/v1 npx expo export --platform web
npx serve -s dist -l 8087
```

### Docker Compose

```bash
cd sevacare-deploy
./deploy.sh up        # Start all services
./deploy.sh status    # Check status
./deploy.sh logs      # View logs
./deploy.sh restart   # Restart
./deploy.sh down      # Stop
```

## Running E2E Tests

Requires backend on port 8081 and frontend on port 8087.

```bash
./sevacare-deploy/run-tests.sh all        # All suites
./sevacare-deploy/run-tests.sh patient    # Patient flow only
./sevacare-deploy/run-tests.sh doctor     # Doctor flow only
./sevacare-deploy/run-tests.sh admin      # Admin flow only
./sevacare-deploy/run-tests.sh api        # API tests only
./sevacare-deploy/run-tests.sh lifecycle  # Full lifecycle
```

## Production Preparation

```bash
cp .env.production.example .env.production
./scripts/build-production.sh
./scripts/deploy-production.sh .env.production up
./scripts/deploy-production.sh .env.production status
```

Use `.env.production` to manage deployment-specific secrets and URLs.

## Test Suites (~67 tests)

| Suite | File | Coverage |
|-------|------|----------|
| Smoke | smoke.spec.ts | Basic navigation |
| Onboarding | onboarding.spec.ts | Landing, search, onboarding form |
| Patient | patient.spec.ts | Login, booking, appointments, prescriptions |
| Doctor | doctor.spec.ts | Dashboard, consultation, schedule |
| Admin | admin.spec.ts | Dashboard, doctor CRUD, patient records |
| API | api.spec.ts | Backend API endpoints, auth |
| Lifecycle | lifecycle.spec.ts | Full tenant lifecycle |

## Ports

| Service | Port |
|---------|------|
| Frontend | 8087 |
| Backend | 8081 |
| PostgreSQL | 5432 |

- `.env.example`
- `docker-compose.yml`
- local PostgreSQL setup
- reverse proxy or API gateway config if needed
- build and release notes for frontend and backend