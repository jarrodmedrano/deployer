# Database Migration Deployment Design

**Date**: 2026-01-24
**Status**: Approved

## Problem Statement

Next.js and other web projects often require database migrations when deploying new versions. Currently, the Dokku deploy action only handles code deployment, not database schema changes. We need a way to run migrations before deploying new app versions.

## Requirements

1. Run database migrations before deploying new app code
2. Use the same Docker image for migrations and deployment
3. Migrations should access the database using existing Dokku config (DATABASE_URL, etc.)
4. Support any migration tool (Prisma, Drizzle, custom scripts)
5. If migrations fail, prevent deployment of new version
6. Zero configuration for projects without migrations

## Assumptions

- All apps have PostgreSQL databases (already created by Terraform)
- Projects use npm/package.json structure
- Migration command is defined as `npm run migrate` in package.json
- Terraform has already linked the database via `dokku postgres:link`

## Design

### Deployment Workflow

```
┌─────────────────────────────────────────────────────────────┐
│ 1. Build Phase (existing)                                   │
│    - Checkout code                                           │
│    - Build Docker image                                      │
│    - Push to DockerHub                                       │
└─────────────────────────────┬───────────────────────────────┘
                              │
┌─────────────────────────────▼───────────────────────────────┐
│ 2. Migration Phase (new)                                    │
│    - SSH to Dokku server                                    │
│    - Check if package.json has "migrate" script             │
│    - If yes:                                                 │
│      - Export all Dokku config vars                         │
│      - Pull the new Docker image                            │
│      - Run migration container with exported env vars       │
│      - Clean up temp files                                  │
│    - If migrations fail, stop here                          │
└─────────────────────────────┬───────────────────────────────┘
                              │
┌─────────────────────────────▼───────────────────────────────┐
│ 3. Deploy Phase (existing)                                  │
│    - Deploy image to Dokku                                  │
│    - Start the app                                           │
└─────────────────────────────────────────────────────────────┘
```

### Migration Execution Details

**Location**: Migrations run on the Dokku server (not GitHub Actions runner)

**Why**: The Dokku server already has:
- Network access to the PostgreSQL database
- All environment variables configured via `dokku config`
- Docker daemon for running containers

**Environment Variables**:
- Use `dokku config:export <app> --merged` to get all config
- Export to temporary file: `/tmp/<app>-env-${{ github.sha }}`
- Pass to Docker: `docker run --env-file /tmp/<app>-env-${{ github.sha }}`
- Clean up after migration completes or fails

**Migration Command**:
```bash
docker run --rm \
  --env-file /tmp/<app>-env-${{ github.sha }} \
  <dockerhub-user>/<image>:${{ github.sha }} \
  npm run migrate
```

**Error Handling**:
- If `npm run migrate` script doesn't exist, skip migrations (exit 0)
- If migration command fails (non-zero exit), stop deployment
- Always clean up temporary env file

## Implementation Changes

### Files to Modify

1. **`.github/workflows/dokku-deploy-action.yml`**
   - Add new step: "Run database migrations" (before "Deploy to Dokku")
   - Check for package.json migrate script
   - Export Dokku config
   - Run migration container
   - Handle failures

### Migration Detection Logic

The action will check if migrations should run by:
1. Extracting package.json from the Docker image
2. Checking if `scripts.migrate` exists
3. If not found, skip migration step (no error)

## Benefits

1. **Safe**: Migrations run before deployment, old app keeps running if migrations fail
2. **Consistent**: Same Docker image used for migrations and deployment
3. **Secure**: Uses production credentials already configured in Dokku
4. **Flexible**: Works with any migration tool (Prisma, Drizzle, custom)
5. **Zero-config**: Projects without migrations are automatically skipped
6. **Environment parity**: Migration runs with exact same env vars as production app

## Risks and Mitigations

**Risk**: Migration succeeds but deployment fails
**Mitigation**: Dokku deployments are atomic - if deployment fails, old version keeps running with the new schema. Most schema changes are backward compatible for one version.

**Risk**: Temporary env file contains secrets
**Mitigation**: File is created with restrictive permissions (600), cleaned up immediately after use, uses unique name with git SHA to avoid conflicts.

**Risk**: Multiple deployments running simultaneously
**Mitigation**: Unique temp file names using `${{ github.sha }}` prevent conflicts.

## Future Enhancements

- Add support for database type/version specification in project config
- Support for rollback migrations if deployment fails
- Support for non-npm projects (Python, Ruby, etc.)
- Dry-run mode to preview migrations
