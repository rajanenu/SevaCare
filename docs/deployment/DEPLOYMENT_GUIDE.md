# 🚀 SevaCare Deployment & Operational Guide

**Complete guide for deploying and managing SevaCare services**

---

## Table of Contents

1. [Quick Start](#quick-start)
2. [Local Development Setup](#local-development-setup)
3. [Service Management](#service-management)
4. [Monitoring & Troubleshooting](#monitoring--troubleshooting)
5. [Production Deployment](#production-deployment)
6. [Best Practices](#best-practices)

---

## Quick Start

### 1. Initial Setup (One Time)
```bash
cd /Users/rajasekharreddy/Documents/SevaCare
./scripts/setup.sh    # Interactive setup wizard
```

### 2. Start Services
```bash
./scripts/start-local.sh    # Complete application
```

### 3. Access Application
- **Frontend:** http://localhost:8087
- **Backend API:** http://localhost:8081/api/v1
- **Logs:** `.logs/backend.log`, `.logs/frontend.log`

### 4. Stop Services
```bash
./scripts/stop-all.sh
```

---

## Local Development Setup

### Prerequisites Checking
```bash
./scripts/setup.sh    # Validates Java, Node, Maven, Git, Docker
```

**Required versions:**
- Java: 17+
- Node.js: 20+
- Maven: 3.9+
- Git: Latest
- PostgreSQL: 15+ (optional)

### Environment Configuration

#### File: `.env.local`
```bash
# Database
DB_HOST=localhost
DB_PORT=5432
DB_NAME=sevacare
DB_USER=postgres
DB_PASSWORD=postgres

# Services
BACKEND_PORT=8081
FRONTEND_PORT=8087
EXPO_PUBLIC_API_BASE_URL=http://localhost:8081/api/v1

# Build
SKIP_TESTS=true
BUILD_THREADS=4
```

**Edit configuration:**
```bash
nano .env.local
```

### Database Setup

#### Initialize Database
```bash
./scripts/db-setup.sh --init
```

#### Check Database Status
```bash
./scripts/db-setup.sh --check
```

#### View Tables
```bash
./scripts/db-setup.sh --tables
```

#### Reset Database (Destructive)
```bash
./scripts/db-setup.sh --reset
```

---

## Service Management

### Start All Services
```bash
./scripts/start-local.sh
```

**Output:**
```
✓ All services started successfully
✓ Local URLs:
  Frontend:     http://localhost:8087
  Backend API:  http://localhost:8081/api/v1

✓ Network URLs (from other machines):
  Frontend:     http://192.168.1.100:8087
  Backend API:  http://192.168.1.100:8081/api/v1
```

### Start Individual Services

#### Backend Only
```bash
./scripts/start-backend.sh
# Running on port 8081
# Logs: .logs/backend.log
```

#### Frontend Only with Custom API
```bash
./scripts/start-frontend.sh http://backend-api-url/api/v1
# Running on port 8087
# Logs: .logs/frontend.log
```

### Stop Services
```bash
./scripts/stop-all.sh              # Stop and keep logs
./scripts/stop-all.sh --clean-logs # Stop and remove logs
```

---

## Monitoring & Troubleshooting

### Quick Status Check
```bash
./scripts/status.sh                # Local services
./scripts/status.sh --network      # Network-accessible
```

**Output:**
```
✓ Backend is RUNNING on http://localhost:8081
✓ Frontend is RUNNING on http://localhost:8087
✓ PostgreSQL is running on localhost:5432
✓ Backend health check passed
✓ Frontend is responsive
```

### Comprehensive Health Check

#### One-Time Check
```bash
./scripts/health-check.sh
```

#### Continuous Monitoring
```bash
./scripts/health-check.sh --watch              # Every 10 seconds
./scripts/health-check.sh --watch --interval 5  # Every 5 seconds
./scripts/health-check.sh --network             # Network URLs
```

### View Service Logs

#### Backend Logs
```bash
./scripts/logs.sh backend              # Last 50 lines
./scripts/logs.sh backend --tail 100   # Last 100 lines
./scripts/logs.sh backend --follow     # Live monitoring
```

#### Frontend Logs
```bash
./scripts/logs.sh frontend
./scripts/logs.sh frontend --follow
```

#### All Logs
```bash
./scripts/logs.sh all
./scripts/logs.sh all --follow
```

#### List Available Logs
```bash
./scripts/logs.sh list
```

### Quick Reference
```bash
./scripts/info.sh              # All information
./scripts/info.sh --urls       # Just URLs
./scripts/info.sh --commands   # Just commands
./scripts/info.sh --docker     # Docker help
```

---

## Troubleshooting Common Issues

### Issue: Port Already in Use

**Symptom:** Error about port 8081 or 8087 already in use

**Solution:**
```bash
# Kill processes on those ports
./stop-all.sh

# Or manually find and kill
lsof -i :8081    # Find process using port 8081
kill -9 <PID>    # Kill it
```

### Issue: Database Connection Failed

**Symptom:** "Cannot connect to PostgreSQL"

**Solution:**
```bash
# Check database status
./scripts/db-setup.sh --check

# Start PostgreSQL if installed locally
brew services start postgresql@15

# Or connect to remote database
# Edit .env.local with correct DB_HOST
```

### Issue: Cannot Access Frontend

**Symptom:** "Cannot reach http://localhost:8087"

**Solution:**
```bash
# Check if frontend is running
./scripts/status.sh

# Check frontend logs
./scripts/logs.sh frontend --tail 50

# Restart frontend
./scripts/stop-all.sh
./scripts/start-frontend.sh
```

### Issue: Backend API Not Responding

**Symptom:** "Backend health check failed"

**Solution:**
```bash
# Check backend status
./scripts/status.sh

# View backend logs
./scripts/logs.sh backend --follow

# Restart backend
./scripts/stop-all.sh
./scripts/start-backend.sh
```

### Issue: Build Failures

**Symptom:** Maven or npm build errors

**Solution:**
```bash
# Check build logs
./scripts/logs.sh list           # See all logs
tail -n 100 .logs/backend-build.log

# Clean and rebuild
./stop-all.sh
rm -rf sevacare-backend/target   # Clean backend
cd sevacare-frontend && npm cache clean --force  # Clean frontend
./scripts/start-local.sh         # Rebuild
```

---

## Production Deployment

### Pre-Deployment Checklist

```bash
# 1. Run health checks
./scripts/health-check.sh

# 2. Verify all services
./scripts/status.sh

# 3. Check database is initialized
./scripts/db-setup.sh --check

# 4. Review configuration
cat .env.local

# 5. Check tests (if enabled)
cd sevacare-backend && mvn test
cd ../sevacare-frontend && npm test
```

### Production Environment Setup

Create `.env.production`:
```bash
# Production Database
DB_HOST=prod-db-host.example.com
DB_PORT=5432
DB_NAME=sevacare_prod
DB_USER=prod_user
DB_PASSWORD=<secure-password>

# Production Services
BACKEND_PORT=8081
BACKEND_URL=https://api.example.com
FRONTEND_PORT=8087
FRONTEND_URL=https://app.example.com
EXPO_PUBLIC_API_BASE_URL=https://api.example.com/api/v1

# Build Configuration
SKIP_TESTS=false
BUILD_THREADS=8
NODE_ENV=production
```

### Docker Deployment

#### Using Docker Compose
```bash
# Start services with Docker
docker-compose up -d

# View logs
docker-compose logs -f backend
docker-compose logs -f frontend

# Stop services
docker-compose down

# Clean up volumes
docker-compose down -v
```

#### Building Production Images
```bash
# Build backend image
cd sevacare-backend
docker build -t sevacare-backend:prod .

# Build frontend image
cd ../sevacare-frontend
docker build -t sevacare-frontend:prod .

# Push to registry
docker tag sevacare-backend:prod registry.example.com/sevacare-backend:prod
docker push registry.example.com/sevacare-backend:prod
```

### Production Service Management

Once deployed, use the same monitoring tools:

```bash
# Check production services
./scripts/status.sh --network

# Monitor health
./scripts/health-check.sh --watch

# View production logs
./scripts/logs.sh backend --follow
./scripts/logs.sh frontend --follow
```

---

## Best Practices

### 1. Regular Monitoring
```bash
# Set up continuous monitoring
./scripts/health-check.sh --watch --interval 10
```

### 2. Log Management
```bash
# Keep logs organized
./scripts/logs.sh list

# Archive old logs periodically
tar -czf logs-backup-$(date +%Y%m%d).tar.gz .logs/

# Clean logs when needed
./scripts/stop-all.sh --clean-logs
```

### 3. Database Backups
```bash
# Backup database before major changes
pg_dump -h localhost -U postgres sevacare > backup-$(date +%Y%m%d).sql

# Restore from backup
psql -h localhost -U postgres sevacare < backup-20240322.sql
```

### 4. Environment Variables
```bash
# Always use .env.local for development
# Never commit passwords to version control
# Use .env.example for template
```

### 5. Automated Deployment
```bash
# Create deployment script wrapper
#!/bin/bash
set -e
./scripts/stop-all.sh
git pull
./scripts/db-setup.sh --check
./scripts/start-local.sh
./scripts/health-check.sh
echo "Deployment complete!"
```

### 6. Performance Optimization
```bash
# Monitor service startup time
time ./scripts/start-local.sh

# Check resource usage
top
ps aux | grep java
ps aux | grep node
```

### 7. Error Handling
```bash
# All scripts exit on error
# Check exit codes
./scripts/start-local.sh
if [ $? -eq 0 ]; then
  echo "Services started successfully"
else
  echo "Startup failed - check logs"
  ./scripts/logs.sh all
fi
```

---

## Useful Commands Summary

```bash
# Setup
./scripts/setup.sh                          # First time setup

# Start/Stop
./scripts/start-local.sh                    # All services
./scripts/start-backend.sh                  # Backend only
./scripts/start-frontend.sh [URL]           # Frontend with custom API
./scripts/stop-all.sh                       # Stop services
./scripts/stop-all.sh --clean-logs          # Stop and clean

# Monitoring
./scripts/status.sh                         # Quick status
./scripts/status.sh --network               # Network status
./scripts/health-check.sh                   # Health report
./scripts/health-check.sh --watch           # Continuous monitoring

# Logs
./scripts/logs.sh backend|frontend|all      # View logs
./scripts/logs.sh [service] --follow        # Live logs
./scripts/logs.sh list                      # List all logs

# Database
./scripts/db-setup.sh --init                # Initialize
./scripts/db-setup.sh --check               # Check status
./scripts/db-setup.sh --reset               # Reset (destructive)

# Info
./scripts/info.sh                           # All info
./scripts/info.sh --urls                    # URLs only
./scripts/info.sh --commands                # Commands only
./scripts/info.sh --env                     # Environment
```

---

## Directory Structure

```
sevacare-backend/           # Spring Boot application
  ├── src/
  ├── pom.xml
  └── target/              # Build artifacts

sevacare-frontend/          # React Native Web application
  ├── src/
  ├── dist/                # Build artifacts
  └── package.json

sevacare-e2e-test/          # E2E tests with Playwright
  ├── src/
  └── package.json

.env.local                  # Local configuration
.env.example                # Configuration template
.logs/                      # Service logs
  ├── backend.log
  ├── frontend.log
  └── ...

scripts/                    # Deployment scripts
  ├── setup.sh
  ├── start-local.sh
  ├── start-backend.sh
  ├── start-frontend.sh
  ├── stop-all.sh
  ├── status.sh
  ├── health-check.sh
  ├── logs.sh
  ├── db-setup.sh
  ├── info.sh
  └── README.md            # This file

shared/                     # Shared configuration
  └── constants/
      └── config.sh        # Centralized config
```

---

## Support & Resources

- **Quick Help:** `./scripts/info.sh`
- **Script Help:** `./scripts/README.md`
- **Issues:** Check `.logs/` directory for detailed error messages
- **Status Check:** `./scripts/health-check.sh`
- **Documentation:** See `REFACTORING_PLAN.md`

---

**Version:** 1.0  
**Last Updated:** 2024  
**Status:** Production Ready ✅  
**Supported Platforms:** macOS, Linux  
**Notes:** All scripts are fully automated and can be chained together.
