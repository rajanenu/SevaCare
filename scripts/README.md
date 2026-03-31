# 📋 SevaCare Scripts Documentation

**Quick Reference for all deployment and management scripts**

---

## 🚀 Quick Start

### First Time Setup
```bash
./setup.sh              # One-time setup wizard (checks prerequisites, creates directories, etc.)
```

### Start Services
```bash
./start-local.sh        # Full stack (Backend + Frontend + DB)
./start-backend.sh      # Backend only
./start-frontend.sh     # Frontend only
```

### Stop Services
```bash
./stop-all.sh           # Stop all services
./stop-all.sh --clean-logs  # Stop and remove log files
```

---

## 📚 Complete Script Reference

### **1. setup.sh** - First-Time Setup Wizard
```bash
./setup.sh
```

**Purpose:** One-time configuration and environment preparation

**What it does:**
- ✅ Checks prerequisites (Java, Node, Maven, Git, Docker)
- ✅ Creates necessary directories (.logs, docs, scripts, shared, etc.)
- ✅ Sets up environment files (.env.example, .env.local)
- ✅ Makes all scripts executable
- ✅ Verifies project structure
- ✅ Provides next steps guide

**When to use:** Run this first before anything else

**Output:** Interactive setup with clear next steps

---

### **2. start-local.sh** - Full Stack Orchestrator
```bash
./start-local.sh [--backend-only|--frontend-only|--all]
```

**Purpose:** Start complete SevaCare application (Backend + Frontend + Database)

**Features:**
- 🔍 Preflight checks (Java, Node, Maven availability)
- 🗄️ PostgreSQL readiness validation
- 🔨 Backend build & start (Maven + JAR)
- 🎨 Frontend build & start (Expo + Node server)
- 📊 Service readiness checks
- 📍 Displays all URLs after success

**Default behavior:** Starts all services

**Options:**
- `--backend-only`: Start only the backend service
- `--frontend-only`: Start only the frontend service
- `--all`: Start all services (same as no option)

**Example:**
```bash
./start-local.sh              # All services
./start-local.sh --backend-only   # Backend only
./start-local.sh --frontend-only  # Frontend only
```

**Output:** 
```
✓ Services started successfully
✓ Local URLs:
  Frontend: http://localhost:8087
  Backend:  http://localhost:8081/api/v1
✓ Network URLs:
  Frontend: http://192.168.1.100:8087
  Backend:  http://192.168.1.100:8081/api/v1
```

---

### **3. start-backend.sh** - Backend Service
```bash
./start-backend.sh
```

**Purpose:** Start only the backend service

**Features:**
- 🗄️ PostgreSQL validation
- 🔨 Maven build with test skip
- 📊 Service readiness checks (port 8081)
- 📝 Detailed logging

**When to use:** When you only need backend development

**Output:** Logs to `.logs/backend.log`

---

### **4. start-frontend.sh** - Frontend Service
```bash
./start-frontend.sh [API_URL]
```

**Purpose:** Start the frontend service with custom or default API URL

**Parameters:**
- `API_URL` (optional): Custom backend API URL (defaults to `http://localhost:8081/api/v1`)

**Example:**
```bash
./start-frontend.sh                                    # Uses default
./start-frontend.sh http://localhost:8081/api/v1      # Explicit local
./start-frontend.sh http://192.168.1.100:8081/api/v1  # Remote backend
```

**Output:** Logs to `.logs/frontend.log`, runs on port 8087

---

### **5. stop-all.sh** - Service Cleanup
```bash
./stop-all.sh [--clean-logs]
```

**Purpose:** Stop all running services

**Features:**
- 🛑 Kill processes on ports 8081, 8087
- 📝 Optional cleanup of .logs directory

**Options:**
- `--clean-logs`: Also delete all log files after stopping

**Example:**
```bash
./stop-all.sh              # Just stop services
./stop-all.sh --clean-logs # Stop and clean logs
```

---

### **6. status.sh** - Service Status
```bash
./status.sh [--network]
```

**Purpose:** Check current status of all services

**What it checks:**
- 📍 Ports (8081, 8087, 5432)
- 🏥 Backend health endpoint
- 🎨 Frontend availability
- 🗄️ Database connectivity
- 📊 Endpoint responses

**Options:**
- `--network`: Check network URLs instead of localhost

**Example:**
```bash
./status.sh            # Check local services
./status.sh --network  # Check network-accessible services
```

**Output:** Visual status report with colors

---

### **7. health-check.sh** - Comprehensive Health Report
```bash
./health-check.sh [--watch] [--network] [--interval N]
```

**Purpose:** Detailed health checks with optional monitoring

**Features:**
- ✅ Port listening status
- 🏥 Backend /actuator/health
- 📡 API endpoint availability
- 🎨 Frontend responsiveness
- 🗄️ Database connectivity
- 📊 Success rate percentage

**Options:**
- `--watch`: Continuous monitoring mode
- `--network`: Check network URLs
- `--interval N`: Check interval in seconds (default: 10)

**Example:**
```bash
./health-check.sh                      # One-time check
./health-check.sh --watch              # Monitor every 10 seconds
./health-check.sh --watch --interval 5 # Monitor every 5 seconds
./health-check.sh --network             # Check network URLs
```

**Output:** Color-coded report (🟢 pass, 🔴 fail, 🟡 warning)

---

### **8. logs.sh** - Log Management
```bash
./logs.sh [backend|frontend|all|list] [--tail N] [--follow]
```

**Purpose:** View and monitor service logs

**Services:**
- `backend`: Backend service logs
- `frontend`: Frontend service logs
- `all`: Both backend and frontend
- `list`: Show all available log files

**Options:**
- `--tail N`: Show last N lines (default: 50)
- `--follow`: Live tail (like `tail -f`)

**Example:**
```bash
./logs.sh backend              # View backend logs (last 50 lines)
./logs.sh frontend --tail 100  # View last 100 lines of frontend logs
./logs.sh backend --follow     # Live monitoring of backend logs
./logs.sh all                  # View both backend and frontend
./logs.sh list                 # Show all available log files
```

**Output:** Formatted log display with timestamps

---

### **9. db-setup.sh** - Database Management
```bash
./db-setup.sh [--init|--check|--tables|--schemas|--reset]
```

**Purpose:** Database initialization and management

**Commands:**
- `--init`: Initialize database and prepare for migrations
- `--check`: Check connection and display status
- `--tables`: List all tables in the database
- `--schemas`: Show schema information
- `--reset`: Drop and recreate the database (requires confirmation)

**Example:**
```bash
./db-setup.sh --init      # Set up database
./db-setup.sh --check     # Verify connection
./db-setup.sh --tables    # List tables
./db-setup.sh --reset     # Fresh database (destructive!)
```

**Output:** Connection status, table count, schema details

---

### **10. info.sh** - Quick Reference & Documentation
```bash
./info.sh [--urls|--commands|--docker|--env|all]
```

**Purpose:** Quick access to URLs, commands, and configuration info

**Options:**
- `--urls`: Display all service URLs
- `--commands`: Show all useful commands
- `--docker`: Docker-related commands
- `--env`: Environment configuration info
- `all`: Show everything (default)

**Example:**
```bash
./info.sh              # Show everything
./info.sh --urls       # Just the URLs
./info.sh --commands   # Just the commands
./info.sh --env        # Configuration info
```

**Output:** Color-formatted reference guide

---

### **11. build-production.sh** - Production Build Artifacts
```bash
./build-production.sh
```

**Purpose:** Generate production-ready backend and frontend artifacts

**What it builds:**
- Backend JAR: `sevacare-backend/sevacare-api/target/sevacare-api-0.0.1-SNAPSHOT.jar`
- Frontend static bundle: `sevacare-frontend/dist`

**Environment:**
- Uses `EXPO_PUBLIC_API_BASE_URL` if provided
- Falls back to `https://api.sevacare.example.com/api/v1`

---

### **12. deploy-production.sh** - Production Docker Deploy
```bash
./deploy-production.sh [ENV_FILE] [up|down|restart|logs|status]
```

**Purpose:** Deploy with production overrides using Docker Compose

**Examples:**
```bash
cp .env.production.example .env.production
./deploy-production.sh .env.production up
./deploy-production.sh .env.production status
./deploy-production.sh .env.production logs
```

**Notes:**
- Uses `sevacare-deploy/docker-compose.yml` + `sevacare-deploy/docker-compose.prod.yml`
- Reads environment values from the selected env file

---

## 📍 Service URLs Reference

### Local Access (Same Machine)
```
Frontend:          http://localhost:8087
Backend API:       http://localhost:8081/api/v1
Backend Health:    http://localhost:8081/actuator/health
Database:          localhost:5432 (sevacare)
```

### Network Access (From Other Machines)
```
Frontend:          http://{LOCAL_IP}:8087
Backend API:       http://{LOCAL_IP}:8081/api/v1
Backend Health:    http://{LOCAL_IP}:8081/actuator/health
```

---

## 🗂️ Log Files Location

All logs are stored in the `.logs/` directory:

```
.logs/
├── backend.log              # Backend service runtime logs
├── backend-build.log        # Backend Maven build logs
├── frontend.log             # Frontend service runtime logs
├── frontend-build.log       # Frontend Expo build logs
├── startup-<timestamp>.log  # Full startup session logs
└── error-<timestamp>.log    # Error logs (if any)
```

**View logs:**
```bash
./logs.sh backend --follow   # Live backend logs
tail -f .logs/backend.log    # Direct tail
```

---

## ⚙️ Configuration Files

### `.env.local` - Environment Configuration
Contains all environment variables for local development:
- Database credentials
- Service ports
- API URLs
- Build settings

**Edit with:**
```bash
nano .env.local          # Edit configuration
cat .env.local          # View configuration
```

### `shared/constants/config.sh` - Centralized Configuration
Central bash script that exports:
- All directory paths
- Service ports (8081, 8087, 5432)
- URLs (local and network)
- Utility functions

---

## 🔧 Troubleshooting

### Port Already in Use
```bash
# Kill service on a port
lsof -i :8087    # Find process on port 8087
kill -9 <PID>    # Kill it

# Or use automatic cleanup
./stop-all.sh    # Kills ports 8081, 8087
```

### Database Connection Issues
```bash
# Check PostgreSQL status
./db-setup.sh --check

# Start PostgreSQL (if installed)
brew services start postgresql@15

# Reset database
./db-setup.sh --reset
```

### Service Not Starting
```bash
# Check health
./health-check.sh

# View logs
./logs.sh all --tail 50

# Check prerequisites
./setup.sh
```

### Network Access Problems
```bash
# Use network mode instead of localhost
./status.sh --network
./health-check.sh --network

# Check your local IP
./scripts/info.sh --urls
```

---

## 📊 Typical Workflow

### 1️⃣ First Time Setup
```bash
./setup.sh                    # One time configuration
./start-local.sh              # Start services
./scripts/health-check.sh     # Verify everything works
```

### 2️⃣ Daily Development
```bash
./start-local.sh              # Start services (or individual scripts)
./logs.sh backend --follow    # Monitor logs in another terminal
# ... do your development ...
./stop-all.sh                 # Stop services when done
```

### 3️⃣ Troubleshooting
```bash
./status.sh                   # Check quick status
./health-check.sh --watch     # Monitor health
./logs.sh all --tail 100      # View recent logs
./db-setup.sh --check         # Verify database
```

---

## 💡 Pro Tips

### Run Services in Separate Terminals
```bash
# Terminal 1: Backend
./start-backend.sh

# Terminal 2: Frontend
./start-frontend.sh

# Terminal 3: Monitor logs
./logs.sh all --follow
```

### Continuous Monitoring
```bash
# Monitor everything
./health-check.sh --watch --interval 5
```

### Quick Status Check During Development
```bash
./status.sh    # Quick 10-second health check
```

### Reset Everything and Start Fresh
```bash
./stop-all.sh --clean-logs
./db-setup.sh --reset
./start-local.sh
```

---

## 📞 Help & Documentation

- **What URLs are available?** → `./info.sh --urls`
- **What commands can I run?** → `./info.sh --commands`
- **Configuration options?** → `./info.sh --env`
- **Full information?** → `./info.sh`
- **Project structure?** → See `../REFACTORING_PLAN.md`

---

## 🎯 Script Dependencies

```
setup.sh
  ├── checks prerequisites (Java, Node, Maven, etc.)
  ├── creates directories and files
  └── prepares environment

start-local.sh / start-backend.sh / start-frontend.sh
  ├── source shared/constants/config.sh
  ├── check prerequisites
  ├── validate ports
  ├── build and start services
  └── log everything to .logs/

stop-all.sh
  ├── source shared/constants/config.sh
  ├── kill processes on specific ports
  └── optionally clean logs

status.sh / health-check.sh
  ├── source shared/constants/config.sh
  ├── check ports and endpoints
  ├── curl health endpoints
  └── report status

logs.sh / db-setup.sh / info.sh
  ├── source shared/constants/config.sh
  └── display information or manage services
```

---

## 📝 Notes

- All scripts are **idempotent** — safe to run multiple times
- All scripts **support both local and network URLs**
- All scripts **log to `.logs/` directory** for troubleshooting
- All scripts **source** `shared/constants/config.sh` for consistency
- Scripts **auto-detect your local IP** for network access
- Logs are **organized by service** for easy debugging

---

**Version:** 1.0  
**Last Updated:** 2024  
**Status:** Production Ready ✅
