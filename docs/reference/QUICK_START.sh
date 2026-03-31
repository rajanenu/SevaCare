#!/usr/bin/env bash
# SevaCare Quick Start - Run this file to display quick start guide
# Usage: cat QUICK_START.sh or source QUICK_START.sh

cat << 'EOF'
╔════════════════════════════════════════════════════════════════════════╗
║                  🏥 SevaCare Quick Start Guide                         ║
╚════════════════════════════════════════════════════════════════════════╝

🚀 FIRST TIME ONLY:
═════════════════════════════════════════════════════════════════════════
  ./scripts/setup.sh            # Complete first-time setup
  
  This will:
    ✓ Check all prerequisites (Java, Node, Maven, etc.)
    ✓ Create necessary directories
    ✓ Set up environment files
    ✓ Guide you through next steps

📍 THEN ACCESS HERE (Remember these URLs):
═════════════════════════════════════════════════════════════════════════
  Frontend:  http://localhost:8087
  Backend:   http://localhost:8081
  API:       http://localhost:8081/api/v1
  Health:    http://localhost:8081/actuator/health

⚡ START SERVICES (After setup):
═════════════════════════════════════════════════════════════════════════
  # Option 1: Start everything (recommended)
  ./scripts/start-local.sh
  
  # Option 2: Start individually
  ./scripts/start-backend.sh         # Terminal 1
  ./scripts/start-frontend.sh        # Terminal 2
  
  # Option 3: With custom API URL
  ./scripts/start-frontend.sh http://192.168.1.100:8081/api/v1

✅ VERIFY EVERYTHING IS RUNNING:
═════════════════════════════════════════════════════════════════════════
  ./scripts/status.sh               # Quick check (10 seconds)
  ./scripts/health-check.sh         # Full report (30 seconds)
  ./scripts/health-check.sh --watch # Monitor live (every 10s)

📊 CHECK LOGS (If anything goes wrong):
═════════════════════════════════════════════════════════════════════════
  ./scripts/logs.sh backend           # Backend logs (last 50 lines)
  ./scripts/logs.sh backend --follow  # Backend logs (live)
  ./scripts/logs.sh frontend          # Frontend logs
  ./scripts/logs.sh all               # Both services

🔑 STOP WHEN DONE:
═════════════════════════════════════════════════════════════════════════
  ./scripts/stop-all.sh              # Stop services
  ./scripts/stop-all.sh --clean-logs # Stop + remove logs

💡 QUICK COMMANDS:
═════════════════════════════════════════════════════════════════════════
  ./scripts/info.sh                 # Show all info
  ./scripts/info.sh --urls          # Just the URLs
  ./scripts/info.sh --commands      # Just commands
  ./scripts/status.sh --network     # Network URLs (from other machines)
  ./scripts/db-setup.sh --check     # Check database

📖 NEED MORE HELP?
═════════════════════════════════════════════════════════════════════════
  ./scripts/README.md               # Detailed script docs
  DEPLOYMENT_GUIDE.md               # Complete deployment guide
  SCRIPTS_INVENTORY.md              # All scripts reference
  REFACTORING_PLAN.md               # Project structure

🎯 TYPICAL WORKFLOW:
═════════════════════════════════════════════════════════════════════════
  Morning:
    1. ./scripts/start-local.sh       ← Start app
    2. Open http://localhost:8087    ← Use frontend
    
  During Day:
    • ./scripts/status.sh             ← Quick check anytime
    • ./scripts/logs.sh backend --follow ← Monitor if needed
    
  End of Day:
    • ./scripts/stop-all.sh           ← Stop services

═════════════════════════════════════════════════════════════════════════

🚨 COMMON ISSUES:
═════════════════════════════════════════════════════════════════════════

Port already in use?
  → ./scripts/stop-all.sh

Can't access services?
  → ./scripts/health-check.sh

Database won't connect?
  → ./scripts/db-setup.sh --check

Need to see detailed logs?
  → ./scripts/logs.sh all --tail 100

Need network access from another machine?
  → ./scripts/status.sh --network
  → Or run: ./scripts/info.sh --urls

═════════════════════════════════════════════════════════════════════════

📍 YOUR LOCAL IP: 
  Check with: ./scripts/info.sh --urls

🎯 NEXT STEP:
  Run this to get started:
  
  ./scripts/setup.sh

═════════════════════════════════════════════════════════════════════════
Version: 1.0 | Production Ready ✅
EOF
