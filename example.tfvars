# Your Vultr API key (get it from https://my.vultr.com/settings/#api)
vultr_api_key = "your-vultr-api-key-here"

# Your SSH public key (contents of ~/.ssh/id_rsa.pub)
ssh_public_key = "ssh-rsa AAAA..."

# Path to your SSH private key file
ssh_private_key_path = "~/.ssh/id_rsa"

# Email address for Let's Encrypt SSL certificates
letsencrypt_email = "your-email@example.com"

# List of apps to create in Dokku with their domains
# Note: You'll need to set up DNS A records for each domain pointing to your instance IP
apps = [
  {
    name = "myapp"
    domain = "myapp.example.com"  # Set up A record for this domain
  },
  {
    name = "api"
    domain = "api.mydomain.com"   # Can be from a different domain
  }
]

# Optional: Override default instance plan (default: vc2-1c-1gb)
# instance_plan = "vc2-2c-4gb"

# Optional: Override default region (default: lax)
# region = "nyc"

# Optional: Override default instance label (default: dokku-server)
# instance_label = "my-dokku-server"

# Optional: Override default hostname (default: dokku)
# hostname = "my-dokku" 