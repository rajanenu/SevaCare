# SevaCare Project Refactoring Plan

## Overview
Complete refactoring to:
- Remove unwanted/duplicate files
- Centralize common utilities
- Optimize project structure
- Ready for local and production deployment
- Create reusable scripts and configurations

## Current State Analysis

### Root Directory Issues
- Multiple documentation files (PHASE2_, PHASE3_, BUTTON_*, etc.)
- Image files mixed with docs (.png, .jpg)
- Figma JSON files
- Unorganized structure

### Recommended Structure
```
SevaCare/
├── docs/                    # All documentation
├── scripts/                 # Deployment & utility scripts
├── shared/                  # Shared configs and utilities
├── sevacare-backend/        # Backend (Spring Boot)
├── sevacare-frontend/       # Frontend (Expo/React Native Web)
├── sevacare-e2e-test/       # E2E tests
├── sevacare-deploy/         # Docker & deployment configs
├── .env.example             # Environment template
├── .env.local              # Local overrides (git ignored)
├── .env.production         # Production config
└── README.md               # Main readme
```

## Refactoring Tasks

### 1. Documentation Cleanup
- Move all docs to `docs/` folder
- Keep only essential README files
- Archive old phase documentation

### 2. Shared Utilities
- `shared/config/` - Centralized configuration
- `shared/scripts/` - Reusable bash scripts
- `shared/constants/` - Shared constants (ports, URLs, etc.)

### 3. Frontend Optimizations
- Move Figma JSON files to docs/
- Clean up unnecessary files
- Optimize bundle size
- Create production build configuration

### 4. Backend Optimizations
- Review dependencies
- Clean up test data
- Optimize startup time

### 5. Deployment Scripts
- `start-local.sh` - Full local stack
- `start-backend.sh` - Backend only
- `start-frontend.sh` - Frontend only
- `deploy-production.sh` - Production deployment
- `stop-all.sh` - Cleanup script

### 6. Environment Management
- Create `.env.example` for all configurations
- Separate local, staging, production configs
- Document all environment variables

## Network Access Setup
- Local Frontend: http://localhost:8087
- Local Backend: http://localhost:8081
- Network Frontend: http://{LOCAL_IP}:8087
- Network Backend: http://{LOCAL_IP}:8081
- Production: To be configured in deployment
