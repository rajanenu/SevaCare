# SevaCare CRUD Coverage Matrix

Last updated: 2026-04-13

## Verification Sources
- Script: scripts/test-all-apis.sh
- Script: scripts/test-admin-apis.sh
- Script: scripts/test-platform-admin-apis.sh
- Playwright: sevacare-e2e-test (full suite)

## Role Coverage

| Role | Domain | Create | Get | Get All | Update | Deactivate | Delete | Verification |
|---|---|---|---|---|---|---|---|---|
| patient | appointment booking | yes | yes | yes | partial | n/a | n/a | test-all-apis.sh + api.spec.ts |
| doctor | records/consult queue | partial | yes | yes | yes | n/a | n/a | test-all-apis.sh + api.spec.ts |
| hospital admin | admin users | yes | yes | yes | yes | yes | yes | test-admin-apis.sh (13/13) |
| hospital admin | doctors | yes | yes | yes | yes | n/a | yes | test-admin-apis.sh + test-all-apis.sh |
| platform admin | platform users | yes | yes | yes | yes | yes | yes | test-platform-admin-apis.sh (10/10) |
| platform admin | tenants/onboarding visibility | n/a | yes | yes | n/a | n/a | n/a | api.spec.ts + platform dashboard flow |

## Notes
- Hospital admin delete parity is now implemented for admin users via DELETE /api/v1/admin/{tenantPublicId}/users/{adminPublicId}.
- Last-active-admin safety is enforced: deleting the last active admin in a tenant is blocked.
- Full Playwright run currently has UI selector and onboarding auth expectation mismatches; see report output for failing tests.
