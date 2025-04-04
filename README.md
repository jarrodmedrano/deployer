# Dokku on Vultr with Terraform

This project sets up a Dokku instance on Vultr using Terraform and configures GitHub Actions for easy deployments.

## Prerequisites

- Vultr account with API key
- Domain name (managed by Vultr)
- SSH key pair
- GitHub account

## Setup

1. Clone this repository
2. Create a `terraform.tfvars` file with your configuration:

```hcl
vultr_api_key = "your-api-key"
domain = "your-domain.com"
ssh_public_key = "your-ssh-public-key"
apps = [
  {
    name = "myapp"
    domain = "app.your-domain.com"
  }
]
```

3. Initialize and apply Terraform:

```bash
terraform init
terraform plan
terraform apply
```

4. Configure GitHub Secrets:
   - `DOKKU_SSH_KEY`: Your SSH private key
   - `DOKKU_HOST`: Your Dokku server's IP address
   - `DOKKU_APP_NAME`: The name of your app in Dokku

## Deployment

1. Push your code to the main branch
2. The GitHub Action will automatically deploy to Dokku

## Manual Deployment

You can also deploy manually using the Dokku CLI:

```bash
# Add Dokku as a remote
git remote add dokku dokku@your-server-ip:app-name

# Deploy
git push dokku main
```

## Security Notes

- Keep your Vultr API key secure
- Use strong SSH keys
- Regularly update Dokku and your applications
- Monitor your server's security

## Maintenance

To update Dokku:

```bash
dokku upgrade
```

To check Dokku status:

```bash
dokku report
```

## Troubleshooting

1. Check Dokku logs:

   ```bash
   dokku logs app-name
   ```

2. Check app status:

   ```bash
   dokku ps:report app-name
   ```

3. Restart an app:
   ```bash
   dokku ps:restart app-name
   ```
