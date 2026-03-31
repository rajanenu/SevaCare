# 📊 SevaCare Complete Script Inventory

**Complete overview of all deployment and management scripts**

---

## 📁 Scripts Directory Structure

```
scripts/
├── setup.sh                 ⚙️  First-time environment setup
├── start-local.sh          🚀 Start complete application
├── start-backend.sh        🔧 Start backend service only
├── start-frontend.sh       🎨 Start frontend service only
├── stop-all.sh             🛑 Stop all services
├── status.sh               📊 Check service status
├── health-check.sh         🏥 Comprehensive health checks
├── logs.sh                 📝 View and manage logs
├── db-setup.sh             🗄️  Database initialization & management
├── info.sh                 ℹ️  Quick reference information
└── README.md               📖 Detailed script documentation
```

---

## 🎯 Script Categories & Workflows

### 🔴 SETUP PHASE
**When:** First time setting up the project

```bash
./setup.sh     # ← Start here (checks prerequisites, creates directories)
  ├── Validates Java, Node, Maven, Git, Docker
  ├── Creates .logs, docs, scripts, shared directories
  ├── Sets up .env.example and .env.local
  └── Displays next steps
```

---

### 🟢 SERVICE STARTUP PHASE
**When:** Ready to start services

**Option A: All Services**
```bash
./start-local.sh   # Complete application on one command
```

**Option B: Individual Services**
```bash
./start-backend.sh              # Backend on port 8081
./start-frontend.sh [API_URL]   # Frontend on port 8087
```

---

### 🔵 MONITORING PHASE
**When:** Services are running, need to verify they're healthy

```bash
./status.sh                 # Quick 10-second status
  └─ Shows: Ports, Endpoints, Database status

./health-check.sh           # Detailed health report (one-time)
  └─ Shows: Port status, Health checks, Success rate

./health-check.sh --watch   # Continuous monitoring every 10s
  └─ Perfect for: Watching service behavior
```

---

### 📖 LOGGING PHASE
**When:** Need to see what services are doing

```bash
./logs.sh backend           # View backend logs
./logs.sh frontend          # View frontend logs
./logs.sh backend --follow  # Live backend logs
./logs.sh all               # Both services
./logs.sh list              # Show all available log files
```

---

### 🗄️ DATABASE PHASE
**When:** Need to manage database

```bash
./db-setup.sh --init        # Set up fresh database
./db-setup.sh --check       # Verify connection
./db-setup.sh --tables      # List tables
./db-setup.sh --schemas     # Show schema info
./db-setup.sh --reset       # Destructive reset
```

---

### 📍 INFORMATION PHASE
**When:** Need quick reference

```bash
./info.sh              # Everything
./info.sh --urls       # Just the URLs
./info.sh --commands   # Available commands
./info.sh --env        # Environment info
./info.sh --docker     # Docker commands
```

---

### 🛑 SHUTDOWN PHASE
**When:** Done for the day

```bash
./stop-all.sh              # Stop services, keep logs
./stop-all.sh --clean-logs # Stop services, delete logs
```

---

## 🔄 Typical Daily Workflow

```
Morning:
  1. ./scripts/start-local.sh       ← Start everything
  2. ./scripts/health-check.sh      ← Verify ready
  3. Browser: http://localhost:8087 ← Start work

During Day:
  • ./scripts/status.sh              ← Quick check
  • ./scripts/logs.sh backend --follow ← Monitor any issues

End of Day:
  • ./scripts/stop-all.sh --clean-logs ← Clean shutdown
```

---

## 📋 Script Features Matrix

| Script | Purpose | Key Features |
|--------|---------|--------------|
| **setup.sh** | Environment setup | Prerequisite checks, dir creation, first-time config |
| **start-local.sh** | Full stack startup | Orchestration, all services, preflight checks, logging |
| **start-backend.sh** | Backend only | Isolated backend, build & start, DB validation |
| **start-frontend.sh** | Frontend only | API flexibility, isolated frontend, custom URL support |
| **stop-all.sh** | Service cleanup | Kill processes, optional log cleanup |
| **status.sh** | Quick status | Port check, endpoint check, local/network modes |
| **health-check.sh** | Deep health | Port, endpoint, health check, success %, watch mode |
| **logs.sh** | Log viewing | Multiple-service logs, tail/follow options, filtering |
| **db-setup.sh** | DB management | Init, check, tables, schemas, reset options |
| **info.sh** | Quick reference | URLs, commands, env config, Docker help |

---

## 🎯 Decision Matrix: Which Script to Use?

### "I want to..."

| Need | Command |
|------|---------|
| **Start application** | `./start-local.sh` |
| **Start only backend** | `./start-backend.sh` |
| **Start only frontend** | `./start-frontend.sh` |
| **Stop everything** | `./stop-all.sh` |
| **Check if services are running** | `./status.sh` |
| **Get detailed health report** | `./health-check.sh` |
| **Monitor services live** | `./health-check.sh --watch` |
| **See backend logs** | `./logs.sh backend --follow` |
| **See frontend logs** | `./logs.sh frontend --follow` |
| **View all logs** | `./logs.sh all` |
| **Initialize database** | `./db-setup.sh --init` |
| **Check database status** | `./db-setup.sh --check` |
| **List database tables** | `./db-setup.sh --tables` |
| **Reset database** | `./db-setup.sh --reset` |
| **View all URLs** | `./info.sh --urls` |
| **See all commands** | `./info.sh --commands` |
| **First-time setup** | `./setup.sh` |
| **Access from another machine** | Use `--network` flag or `./info.sh --urls` |

---

## 🔌 Ports & Endpoints Quick Reference

```
LOCAL (http://localhost):
  Frontend:       8087
  Backend:        8081
  Database:       5432

ENDPOINTS:
  Backend Health:  http://localhost:8081/actuator/health
  Public Tenants:  http://localhost:8081/api/v1/public/tenants
  API Base:        http://localhost:8081/api/v1

NETWORK (http://{LOCAL_IP}):
  Replace {LOCAL_IP} with your machine's IP address
  Example: http://192.168.1.100:8087
```

---

## 📊 Service Dependency Map

```
setup.sh ──────────────────────────────┐
  ├─ Checks prerequisites               │
  ├─ Creates directories                │
  └─ Sets up environment                │
                                        ▼
                             start-local.sh
                             /    |    \
                            /     |     \
                 Backend ◄─┘      │      └─► Frontend
                (port 8081)       │    (port 8087)
                                  │
              PostgreSQL ◄────────┘
              (port 5432)
                   │
                   ▼
              db-setup.sh
              
                   ▼
            
            status.sh / health-check.sh / logs.sh
            
                   │
                   ▼
            
              stop-all.sh
```

---

## 🚀 Quick Launch Commands

### Launch Everything
```bash
./scripts/start-local.sh
```

### Launch Your Way
```bash
./scripts/start-backend.sh  &  # Terminal 1
./scripts/start-frontend.sh &  # Terminal 2
./scripts/logs.sh all --follow # Terminal 3
```

### Monitor While Working
```bash
./scripts/health-check.sh --watch    # In a separate terminal
```

### Quick Protocol Check
```bash
./scripts/status.sh          # Every minute during work
./scripts/health-check.sh    # When something seems wrong
./scripts/logs.sh [service]  # When debugging
```

---

## 💾 Configuration Files

| File | Purpose | Edit? |
|------|---------|-------|
| `.env.example` | Template config | ✓ Reference only |
| `.env.local` | Your local config | ✓ Edit for your setup |
| `shared/constants/config.sh` | Central script config | ✓ For advanced users |

---

## 📂 Log File Organization

```
.logs/
├── backend.log              # Backend runtime output
├── backend-build.log        # Maven build output  
├── frontend.log             # Frontend runtime output
├── frontend-build.log       # Expo build output
├── startup-<timestamp>.log  # Full startup session
└── error-<timestamp>.log    # Errors (if any)

Usage:
  tail -f .logs/backend.log           # Live backend
  tail -50 .logs/backend-build.log    # Last 50 build lines
  ./scripts/logs.sh backend --follow  # Easy viewing
  ./scripts/stop-all.sh --clean-logs  # Remove all logs
```

---

## 🛠️ Utilities & Helper Commands

### Check Prerequisites
```bash
java -version       # Java version
node --version      # Node version
mvn --version       # Maven version
npm --version       # NPM version
docker --version    # Docker version
```

### Network Checking
```bash
./scripts/status.sh --network       # Check network URLs
./scripts/health-check.sh --network # Health via network
```

### Manual Service Checks
```bash
# Frontend reachable?
curl http://localhost:8087

# Backend API reachable?
curl http://localhost:8081/api/v1/public/tenants

# Backend health?
curl http://localhost:8081/actuator/health

# Database accessible?
pg_isready -h localhost -p 5432
```

### Manual Port Cleanup
```bash
lsof -i :8081           # Find process on backend port
lsof -i :8087           # Find process on frontend port
kill -9 <PID>           # Kill the process
./scripts/stop-all.sh   # Or use script (easier)
```

---

## 🔐 Security Considerations

### Database Credentials
```bash
# ✓ DO: Store secure credentials in .env.local
DB_PASSWORD=<strong-password>

# ✗ DON'T: Commit .env.local to git
# (only commit .env.example with dummy values)
```

### Port Access
```bash
# Services listen on localhost by default
# To access from other machines, use network mode
./scripts/status.sh --network
```

### Log Files
```bash
# Logs contain application information
# Keep logs confidential in production
./scripts/stop-all.sh --clean-logs  # Clean up
```

---

## 🎓 Learning Path

**New to SevaCare? Follow this path:**

1. **Day 1:** `./setup.sh` → Read output
2. **Day 1:** `./start-local.sh` → Services start
3. **Day 1:** `./scripts/info.sh` → Learn URLs
4. **Day 2:** `./status.sh` → Check services
5. **Day 2:** `./logs.sh all` → See logs
6. **Day 3:** `./health-check.sh --watch` → Monitor live
7. **Advanced:** Read `scripts/README.md` for details

---

## ⚡ Performance Tips

### Faster Startup
```bash
# Uses all scripts intelligently
./scripts/start-local.sh

# Typical times:
# Backend:  20-40 seconds (first run), 5-10 seconds (cached)
# Frontend: 15-30 seconds (first run), 2-5 seconds (cached)
```

### Faster Restarts
```bash
# Stop and start only what you need
./scripts/stop-all.sh
./scripts/start-backend.sh  # If only backend changed

# Both services on separate terminals (no waiting)
./scripts/start-backend.sh &
./scripts/start-frontend.sh &
wait
```

---

## 📞 Troubleshooting Quick Links

| Problem | Solution |
|---------|----------|
| Port in use | `./scripts/stop-all.sh` |
| DB connection failed | `./scripts/db-setup.sh --check` |
| Services won't start | `./scripts/health-check.sh` |
| Can't see logs | `./scripts/logs.sh list` |
| Network access issues | `./scripts/status.sh --network` |
| Can't access from other machines | `./scripts/info.sh --urls` |

---

## 📚 Additional Resources

- **Detailed Scripts:** `scripts/README.md`
- **Deployment Guide:** `DEPLOYMENT_GUIDE.md`
- **Project Structure:** `REFACTORING_PLAN.md`
- **Configuration:** `shared/constants/config.sh`
- **Button Design:** `BUTTON_DESIGN.md` (from Phase 1)

---

## ✅ Common Scenarios Solved

### Scenario 1: Fresh Start (First Time)
```bash
./setup.sh              # Prerequisites + config
./scripts/start-local.sh  # Start application
./scripts/status.sh     # Verify
→ Ready for development!
```

### Scenario 2: Port Already in Use
```bash
./scripts/stop-all.sh   # Kill existing services
./scripts/start-local.sh  # Fresh start
→ Services running clean!
```

### Scenario 3: Database Issues
```bash
./scripts/db-setup.sh --check     # Check connection
./scripts/db-setup.sh --reset     # Start fresh
./scripts/start-local.sh          # Run migrations
→ Database ready!
```

### Scenario 4: Debugging Production Issue
```bash
./scripts/status.sh         # Quick check
./scripts/health-check.sh   # Detailed check
./scripts/logs.sh all --tail 100  # Last 100 lines
./scripts/logs.sh backend --follow  # Live monitoring
→ Problem identified and monitored!
```

### Scenario 5: Network Access Needed
```bash
./scripts/info.sh --urls           # See all URLs
./scripts/status.sh --network      # Network status
./scripts/health-check.sh --network  # Network health
→ Access from any machine on network!
```

---

**Status:** ✅ All Scripts Documented & Ready  
**Last Updated:** 2024  
**Maintenance:** Scripts self-validate and provide clear error messages
