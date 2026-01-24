# Database Migration Deployment Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add database migration support to the Dokku deploy GitHub Action workflow

**Architecture:** Insert a new migration step between "Build and push Docker image" and "Deploy to Dokku". The migration step runs on the Dokku server using the newly built Docker image with all Dokku environment variables exported.

**Tech Stack:** GitHub Actions, SSH, Docker, Dokku, Bash

---

## Task 1: Add Migration Step to Workflow

**Files:**
- Modify: `.github/workflows/dokku-deploy-action.yml:74-75` (insert new step between Build and Deploy)

**Step 1: Add migration step after build**

Insert the new step between the "Build and push Docker image" step and the "Deploy to Dokku" step:

```yaml
      - name: Run database migrations
        run: |
          # Pull the newly built image to Dokku server
          ssh dokku@${{ secrets.DOKKU_HOST }} "docker pull ${{ secrets.DOCKERHUB_USERNAME }}/${{ inputs.docker_image_name }}:${{ github.sha }}"

          # Check if package.json has a migrate script
          HAS_MIGRATE=$(ssh dokku@${{ secrets.DOKKU_HOST }} "docker run --rm ${{ secrets.DOCKERHUB_USERNAME }}/${{ inputs.docker_image_name }}:${{ github.sha }} sh -c 'if [ -f package.json ] && grep -q \"\\\"migrate\\\"\" package.json; then echo yes; else echo no; fi'")

          if [ "$HAS_MIGRATE" = "yes" ]; then
            echo "Migration script found, running migrations..."

            # Export Dokku config to temporary file
            ENV_FILE="/tmp/${{ inputs.app_name }}-env-${{ github.sha }}"
            ssh dokku@${{ secrets.DOKKU_HOST }} "dokku config:export ${{ inputs.app_name }} --merged > $ENV_FILE && chmod 600 $ENV_FILE"

            # Run migrations
            ssh dokku@${{ secrets.DOKKU_HOST }} "docker run --rm --env-file $ENV_FILE ${{ secrets.DOCKERHUB_USERNAME }}/${{ inputs.docker_image_name }}:${{ github.sha }} npm run migrate"
            MIGRATION_EXIT=$?

            # Clean up temporary env file
            ssh dokku@${{ secrets.DOKKU_HOST }} "rm -f $ENV_FILE"

            # Exit if migration failed
            if [ $MIGRATION_EXIT -ne 0 ]; then
              echo "Migration failed with exit code $MIGRATION_EXIT"
              exit $MIGRATION_EXIT
            fi

            echo "Migrations completed successfully"
          else
            echo "No migration script found in package.json, skipping migrations"
          fi
```

**Step 2: Verify workflow syntax**

The YAML should be properly indented at the same level as other steps. The new step should be between lines 74 and 75 of the original file.

**Step 3: Commit the changes**

```bash
git add .github/workflows/dokku-deploy-action.yml
git commit -m "feat: add database migration step to deploy workflow

- Pull Docker image to Dokku server before deployment
- Check for 'migrate' script in package.json
- Export Dokku config vars to temporary file
- Run migrations using Docker container with env vars
- Clean up temp file and fail deployment if migrations fail
- Skip migrations gracefully if no migrate script exists

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 2: Update Documentation

**Files:**
- Modify: `README.md` (add migration documentation)

**Step 1: Add migration section to README**

Add a new section after the "Deployment" section:

```markdown
## Database Migrations

The deployment workflow automatically runs database migrations before deploying new versions.

### How it works

1. After building and pushing your Docker image, the workflow checks if your project has a `migrate` script in `package.json`
2. If found, it exports all Dokku environment variables (including `DATABASE_URL`)
3. Runs `npm run migrate` using the newly built Docker image with your production database
4. If migrations succeed, deployment continues
5. If migrations fail, deployment stops and your old version keeps running

### Setup

Add a `migrate` script to your project's `package.json`:

```json
{
  "scripts": {
    "migrate": "prisma migrate deploy"
  }
}
```

Or for other tools:

```json
{
  "scripts": {
    "migrate": "drizzle-kit push",
    // or
    "migrate": "node scripts/migrate.js"
  }
}
```

### Projects without migrations

If your project doesn't have a `migrate` script in `package.json`, the migration step is automatically skipped. No configuration needed.

### Troubleshooting

If migrations fail:
1. Check the GitHub Actions logs for the error message
2. The old app version will continue running
3. Fix the migration issue and push a new commit
4. Migrations run in the same environment as your app (same DATABASE_URL, same env vars)
```

**Step 2: Commit documentation**

```bash
git add README.md
git commit -m "docs: add database migration documentation

Explain how automatic migrations work during deployment and how
to configure migrate scripts in package.json.

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 3: Test Plan Documentation

**Files:**
- Create: `docs/testing/migration-deployment-tests.md`

**Step 1: Document testing scenarios**

Create a test plan document:

```markdown
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
```

**Step 2: Commit test plan**

```bash
git add docs/testing/migration-deployment-tests.md
git commit -m "docs: add migration deployment test scenarios

Document test cases for migration workflow including success,
skip, and failure scenarios.

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Implementation Notes

- **YAGNI**: No support for rollback migrations (can be added later if needed)
- **DRY**: Reuse existing SSH connection and Dokku config system
- **Security**: Temporary env file uses restrictive permissions (600) and unique name with git SHA
- **Zero-config**: Projects without migrations work without any changes

## Verification

After implementation:
1. Workflow YAML should be syntactically valid
2. Documentation should clearly explain how to use migrations
3. Test plan should cover all scenarios from design document
4. All commits should follow conventional commit format
