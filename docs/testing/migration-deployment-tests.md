# Migration Deployment Testing

## Test Scenarios

### Scenario 1: Project with migrate script
**Setup:**
- Create test Next.js project with Prisma
- Add `"migrate": "prisma migrate deploy"` to package.json
- Create a simple Prisma migration

**Expected:**
- Migration step detects migrate script
- Exports Dokku config
- Runs migration successfully
- Continues to deployment

### Scenario 2: Project without migrate script
**Setup:**
- Create test project without migrate script in package.json

**Expected:**
- Migration step skips gracefully
- Logs "No migration script found"
- Continues to deployment

### Scenario 3: Migration failure
**Setup:**
- Create project with intentionally failing migration
- Example: SQL syntax error, constraint violation

**Expected:**
- Migration fails with non-zero exit code
- Deployment stops
- Old app version continues running
- Error logged in GitHub Actions

### Scenario 4: Non-Node.js project
**Setup:**
- Create project without package.json (Python, Go, etc.)

**Expected:**
- Migration step skips gracefully
- Continues to deployment

## Manual Testing Steps

1. Create test app in Dokku: `dokku apps:create test-migrations`
2. Link database: `dokku postgres:link test-db test-migrations`
3. Deploy using workflow with each scenario above
4. Verify behavior matches expectations
5. Clean up: `dokku apps:destroy test-migrations`
