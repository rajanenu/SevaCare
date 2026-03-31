# 🎯 SevaCare - Getting Started Guide

**Step-by-step guide to get SevaCare running on your machine**

---

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Project Overview](#project-overview)
3. [Setup Steps](#setup-steps)
4. [Accessing the Application](#accessing-the-application)
5. [Daily Development Workflow](#daily-development-workflow)
6. [Troubleshooting](#troubleshooting)

---

## Prerequisites

Before starting, ensure you have:

### Required Software

| Software | Version | Install |
|----------|---------|---------|
| **Java** | 17+ | `brew install openjdk@17` |
| **Node.js** | 20+ | `brew install node` |
| **Maven** | 3.9+ | `brew install maven` |
| **Git** | Latest | `brew install git` |

### Optional (But Recommended)

| Software | Purpose | Install |
|----------|---------|---------|
| **Docker** | Containerized deployment | `brew install docker` |
| **PostgreSQL** | Local database (if not using cloud) | `brew install postgresql@15` |

### Verify Installation

```bash
# Open a terminal and run:
java -version       # Should show Java 17+
node --version      # Should show v20+
mvn --version       # Should show 3.9+
git --version       # Should show latest
```

If any command is not found, install the missing software first.

---

## Project Overview

### What is SevaCare?

SevaCare is a **full-stack healthcare management application** with:

- **Backend**: Spring Boot REST API (Java)
- **Frontend**: React Native Web Application (TypeScript)
- **Database**: PostgreSQL
- **Testing**: Playwright E2E Tests

### Project Structure

```
SevaCare/                          # Main project directory
├── sevacare-backend/              # 🔌 Backend API (Spring Boot)
│   └── Runs on port 8081
├── sevacare-frontend/             # 🎨 Frontend (React Native Web)
│   └── Runs on port 8087
├── sevacare-e2e-test/             # 🧪 End-to-End Tests
├── scripts/                       # 📜 Automation Scripts
│   ├── start-local.sh
│   ├── stop-all.sh
│   ├── status.sh
│   └── ... (more scripts)
├── docs/                          # 📖 Documentation
├── .logs/                         # 📝 Log files
├── .env.local                     # ⚙️  Configuration
└── shared/                        # 🔧 Shared utilities
    └── constants/
        └── config.sh
```

### Service Ports

```
Backend:    http://localhost:8081     (REST API)
Frontend:   http://localhost:8087     (Web App)
Database:   localhost:5432            (PostgreSQL)
```

### Key Features

- 🏥 Healthcare facility management
- 👥 User and tenant management
- 🎯 Multi-tenant architecture
- 🔐 Secure authentication
- 📊 Dashboard and analytics
- 🎨 Modern responsive UI

---

## Setup Steps

### Step 1: Clone/Prepare the Project

```bash
# Navigate to project directory
cd /Users/rajasekharreddy/Documents/SevaCare

# Verify structure
ls -la        # Should show sevacare-backend, sevacare-frontend, etc.
```

### Step 2: Run the Setup Wizard

```bash
# Make scripts executable and run setup
chmod +x scripts/*.sh
./scripts/setup.sh
```

**What this does:**
- ✅ Verifies all prerequisites are installed
- ✅ Creates necessary directories (.logs, docs, etc.)
- ✅ Sets up configuration files (.env.local, etc.)
- ✅ Displays next steps

**Example Output:**
```
✓ Java 17 Found (version 17.0.5)
✓ Node 20 Found (v20.10.0)
✓ Maven 3.9 Found (Apache Maven 3.9.5)
✓ All prerequisites satisfied
✓ All setup tasks completed!
```

### Step 3: Start Services

```bash
# Start everything (recommended for first time)
./scripts/start-local.sh
```

**What happens:**
1. Checks for port conflicts
2. Validates PostgreSQL is running
3. Builds and starts Backend (port 8081)
4. Builds and starts Frontend (port 8087)
5. Displays all URLs

**Example Output:**
```
✓ All services started successfully

✓ Local URLs:
  Frontend: http://localhost:8087
  Backend:  http://localhost:8081/api/v1

✓ Network URLs:
  Frontend: http://192.168.1.100:8087
  Backend:  http://192.168.1.100:8081/api/v1

✓ Log files at: .logs/
```

### Step 4: Verify Everything Works

```bash
# In a new terminal, check status
./scripts/health-check.sh
```

**Expected Output:**
```
✓ PASS - Backend on port 8081
✓ PASS - Frontend on port 8087
✓ CONNECTED - PostgreSQL
✓ PASS - Backend health check
✓ PASS - Frontend responsive

✓ Success Rate: 100%
✓ ALL SYSTEMS OPERATIONAL
```

---

## Accessing the Application

### From Your Computer (Localhost)

Open your browser and navigate to:

```
http://localhost:8087
```

**What you'll see:**
- SevaCare healthcare application interface
- Login screen (or dashboard if already logged in)
- Fully functional web application

### From Another Machine (Network)

Get your local IP first:

```bash
./scripts/info.sh --urls
```

Look for "Your local IP" in the output (e.g., `192.168.1.100`).

Then open in any browser on your network:

```
http://192.168.1.100:8087
```

### API Endpoints

Backend API is available at:

- **API Base**: `http://localhost:8081/api/v1`
- **Health Check**: `http://localhost:8081/actuator/health`
- **Public Tenants**: `http://localhost:8081/api/v1/public/tenants`

Test from command line:

```bash
# Get health status
curl http://localhost:8081/actuator/health

# List public tenants
curl http://localhost:8081/api/v1/public/tenants

# Full API information (from backend logging)
./scripts/logs.sh backend | grep -i "endpoint\|route"
```

---

## Daily Development Workflow

### Morning: Start Work

```bash
# 1. Start services
./scripts/start-local.sh

# 2. Verify everything is running
./scripts/status.sh

# 3. Open application
open http://localhost:8087
```

### During Day: Development

```bash
# Monitor backend in separate terminal
./scripts/logs.sh backend --follow

# Monitor frontend in another terminal
./scripts/logs.sh frontend --follow

# Quick status check
./scripts/status.sh

# Full health report (if issues)
./scripts/health-check.sh
```

### Evening: Stop Services

```bash
# Clean shutdown
./scripts/stop-all.sh

# Or clean up logs too
./scripts/stop-all.sh --clean-logs
```

### Multiple Day Scenario

```bash
# Day 1: Initial setup
./scripts/setup.sh
./scripts/start-local.sh

# Day 2: Continue work
./scripts/start-local.sh
# Open http://localhost:8087
# ... work on features ...
./scripts/stop-all.sh

# Day 3: Fresh start
./scripts/start-local.sh
# Continue...
```

---

## Project Navigation

### Backend Development

```bash
# Open backend code
cd sevacare-backend

# View structure
tree src/main/java/com/example/sevacare
# or
ls -la src/main/java/com/example/sevacare/

# Build backend only
mvn clean install

# Run tests
mvn test

# View backend logs
../scripts/logs.sh backend --follow
```

### Frontend Development

```bash
# Open frontend code
cd sevacare-frontend

# View structure
tree src/
# or
ls -la src/

# Install dependencies
npm install

# Build frontend
npm run build

# View frontend logs
../scripts/logs.sh frontend --follow
```

### Database Management

```bash
# View database status
./scripts/db-setup.sh --check

# View tables
./scripts/db-setup.sh --tables

# Reset database (carefully!)
./scripts/db-setup.sh --reset
```

---

## Troubleshooting

### Issue: "Port 8081 already in use"

**Symptom:**
```
Error: port 8081 is already in use
```

**Solution:**
```bash
# Stop running services
./scripts/stop-all.sh

# Verify ports are free
./scripts/status.sh

# Start again
./scripts/start-local.sh
```

### Issue: "Cannot connect to PostgreSQL"

**Symptom:**
```
Error: Cannot connect to database
```

**Solution:**
```bash
# Check if PostgreSQL is running
./scripts/db-setup.sh --check

# Start PostgreSQL (if installed locally)
brew services start postgresql@15

# Or verify settings in .env.local
cat .env.local | grep DB_
```

### Issue: "Frontend shows blank page"

**Symptom:**
```
Browser shows blank page or connection refused
```

**Solution:**
```bash
# Check frontend is running
./scripts/status.sh

# View frontend logs
./scripts/logs.sh frontend --tail 50

# Verify API URL is correct
cat .env.local | grep EXPO_PUBLIC_API_BASE_URL

# Rebuild frontend
./scripts/stop-all.sh
./scripts/start-frontend.sh
```

### Issue: "Backend not responding"

**Symptom:**
```
Backend health check failed
```

**Solution:**
```bash
# Check backend status
./scripts/health-check.sh

# View backend logs for errors
./scripts/logs.sh backend --tail 100

# Rebuild backend
./scripts/stop-all.sh
./scripts/start-backend.sh
```

### Issue: "Can't access from other machine"

**Symptom:**
```
http://192.168.x.x:8087 gives "connection refused"
```

**Solution:**
```bash
# Check what IP services are using
./scripts/info.sh --urls

# Start with network mode
./scripts/status.sh --network

# Verify firewall isn't blocking ports
# macOS: System Preferences > Security & Privacy > Firewall
```

### Issue: "Scripts permission denied"

**Symptom:**
```
-bash: ./scripts/start-local.sh: Permission denied
```

**Solution:**
```bash
# Make scripts executable
chmod +x scripts/*.sh

# Verify
ls -la scripts/*.sh  # Should see "x" permissions
```

---

## Environment Configuration

### Understanding .env.local

The `.env.local` file contains all configuration:

```bash
# Database Connection
DB_HOST=localhost
DB_PORT=5432
DB_NAME=sevacare
DB_USER=postgres
DB_PASSWORD=postgres

# Service Ports
BACKEND_PORT=8081
FRONTEND_PORT=8087

# API Configuration
EXPO_PUBLIC_API_BASE_URL=http://localhost:8081/api/v1
```

### Customizing Configuration

```bash
# Edit settings
nano .env.local

# Common changes:
# 1. Database host (for remote DB):
#    DB_HOST=prod-db.example.com
# 2. API URL (for different backend):
#    EXPO_PUBLIC_API_BASE_URL=http://different-api:8081/api/v1
# 3. Ports (if 8081/8087 are in use):
#    BACKEND_PORT=9001
#    FRONTEND_PORT=9002

# Save and restart
./scripts/stop-all.sh
./scripts/start-local.sh
```

---

## Next Steps

### Once Everything is Running

1. **Explore the Dashboard**
   - Navigate to http://localhost:8087
   - Familiarize yourself with the interface

2. **Review Code**
   - Backend: `sevacare-backend/src/`
   - Frontend: `sevacare-frontend/src/`

3. **Check Logs During Use**
   - `./scripts/logs.sh all --follow`
   - Watch logs as you interact with the app

4. **Run Tests**
   ```bash
   cd sevacare-e2e-test
   npx playwright test
   ```

5. **Make Changes**
   - Edit backend or frontend code
   - Services should auto-reload (or restart as needed)
   - Logs will show what's happening

### Getting Help

```bash
# Quick reference
./scripts/info.sh

# Detailed script info
cat scripts/README.md

# Full deployment guide
cat DEPLOYMENT_GUIDE.md

# Project structure
cat REFACTORING_PLAN.md
```

---

## Common Commands Cheat Sheet

```bash
# Startup
./scripts/setup.sh                  # First time only
./scripts/start-local.sh            # Start all services
./scripts/start-backend.sh          # Start backend only
./scripts/start-frontend.sh         # Start frontend only

# Monitoring
./scripts/status.sh                 # Quick status
./scripts/health-check.sh           # Full health
./scripts/health-check.sh --watch   # Monitor live
./scripts/logs.sh backend --follow  # Backend logs
./scripts/logs.sh frontend --follow # Frontend logs

# Database
./scripts/db-setup.sh --check       # Check DB
./scripts/db-setup.sh --tables      # List tables

# Info
./scripts/info.sh                   # All info
./scripts/info.sh --urls            # Just URLs
./scripts/info.sh --commands        # Just commands

# Shutdown
./scripts/stop-all.sh               # Stop services
./scripts/stop-all.sh --clean-logs  # Stop + clean
```

---

## Support Resources

- **This Guide**: `GETTING_STARTED.md` (you're reading it!)
- **Scripts Help**: `scripts/README.md`
- **Deployment**: `DEPLOYMENT_GUIDE.md`
- **Scripts Index**: `SCRIPTS_INVENTORY.md`
- **Project Plan**: `REFACTORING_PLAN.md`
- **Quick Reference**: `./scripts/info.sh`

---

**You're all set! Now go build something amazing with SevaCare! 🚀**

---

**Version:** 1.0  
**Last Updated:** 2024  
**Status:** Ready for Development ✅
