terraform {
  required_providers {
    vultr = {
      source  = "vultr/vultr"
      version = "~> 2.0"
    }
  }
}

provider "vultr" {
  api_key = var.vultr_api_key
}

# Create a Vultr instance
resource "vultr_instance" "dokku" {
  plan     = var.instance_plan
  region   = var.region
  os_id    = var.os_id
  label    = var.instance_label
  hostname = var.hostname
  ssh_key_ids = [vultr_ssh_key.dokku.id]

  user_data = <<-EOF
              #!/bin/bash
              
              # Enable logging
              exec 1> >(tee -a /var/log/user-data.log)
              exec 2>&1
              
              echo "Starting user-data script..."
              
              # Update system
              echo "Updating system..."
              apt-get update
              apt-get upgrade -y
              apt-get dist-upgrade -y
              
              # Install required packages
              echo "Installing required packages..."
              apt-get install -y apt-transport-https ca-certificates curl gnupg2 lsb-release software-properties-common
              
              # Set timezone
              echo "Setting timezone..."
              mv /etc/localtime /etc/localtime.bak
              ln -s /usr/share/zoneinfo/UTC /etc/localtime
              service cron restart
              
              # Setup swap space
              echo "Setting up swap space..."
              mkdir -p /var/swap
              dd if=/dev/zero of=/var/swap/swap0 bs=1M count=2048
              chmod 600 /var/swap/swap0
              mkswap /var/swap/swap0
              swapon /var/swap/swap0
              echo '/var/swap/swap0 swap swap defaults 0 0' >> /etc/fstab
              
              # Install Docker
              echo "Installing Docker..."
              curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
              echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
              apt-get update
              apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin docker-buildx-plugin
              
              # Install Dokku
              echo "Installing Dokku..."
              curl -fsSL https://packagecloud.io/dokku/dokku/gpgkey | apt-key add -
              echo "deb https://packagecloud.io/dokku/dokku/ubuntu/ $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/dokku.list
              apt-get update
              
              # Pre-configure Dokku options for non-interactive installation
              echo "dokku dokku/vhost_enable boolean true" | debconf-set-selections
              echo "dokku dokku/hostname string ${var.hostname}" | debconf-set-selections
              echo "dokku dokku/skip_key_file boolean true" | debconf-set-selections
              
              # Install Dokku non-interactively
              DEBIAN_FRONTEND=noninteractive apt-get install -y dokku
              
              # Install Dokku plugins
              echo "Installing Dokku plugins..."
              dokku plugin:install https://github.com/dokku/dokku-letsencrypt.git
              
              # Configure global Let's Encrypt settings
              echo "Configuring global Let's Encrypt settings..."
              dokku letsencrypt:set --global email ${var.letsencrypt_email}
              
              # Create dokku user if it doesn't exist
              echo "Creating dokku user..."
              if ! id -u dokku >/dev/null 2>&1; then
                useradd -m -s /bin/bash dokku
                usermod -aG sudo dokku
                usermod -aG docker dokku
                echo "dokku ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/dokku
                chmod 0440 /etc/sudoers.d/dokku
              fi
              
              # Wait for dokku command to be available
              echo "Waiting for dokku command..."
              for i in {1..30}; do
                if which dokku > /dev/null 2>&1; then
                  echo "Dokku command is available!"
                  break
                fi
                echo "Attempt $i: Dokku command not found, waiting..."
                sleep 5
              done
              
              # Verify dokku installation
              echo "Verifying Dokku installation..."
              if ! which dokku > /dev/null 2>&1; then
                echo "Dokku installation failed!"
                exit 1
              fi
              dokku version
              
              # Create a flag file when installation is complete
              echo "Creating installation flag file..."
              touch /var/log/dokku-installed
              
              echo "User-data script completed!"
              EOF
}

# Create SSH key for instance access
resource "vultr_ssh_key" "dokku" {
  name    = "dokku-ssh-key"
  ssh_key = var.ssh_public_key
}

# Create a terraform_data resource to manage Dokku apps
resource "terraform_data" "dokku_apps" {
  # Use local-exec to run commands on the remote server
  provisioner "local-exec" {
    command = <<-EOT
      # Function to check if a command exists
      check_command() {
        ssh -i "${var.ssh_private_key_path}" -o StrictHostKeyChecking=no -o PasswordAuthentication=no -o PubkeyAuthentication=yes root@${vultr_instance.dokku.main_ip} "which $1 > /dev/null 2>&1"
      }

      # Function to check logs
      check_logs() {
        ssh -i "${var.ssh_private_key_path}" -o StrictHostKeyChecking=no -o PasswordAuthentication=no -o PubkeyAuthentication=yes root@${vultr_instance.dokku.main_ip} "cat /var/log/user-data.log"
      }

      # Wait for SSH to be available
      echo "Waiting for SSH to be ready..."
      until ssh -i "${var.ssh_private_key_path}" -o StrictHostKeyChecking=no -o PasswordAuthentication=no -o PubkeyAuthentication=yes root@${vultr_instance.dokku.main_ip} 'echo "SSH is ready"'; do
        echo "SSH not ready yet, waiting..."
        sleep 10
      done
      echo "SSH is ready!"

      # Check installation logs
      echo "Checking installation logs..."
      check_logs

      # Wait for Dokku installation to complete
      echo "Waiting for Dokku installation to complete..."
      until ssh -i "${var.ssh_private_key_path}" -o StrictHostKeyChecking=no -o PasswordAuthentication=no -o PubkeyAuthentication=yes root@${vultr_instance.dokku.main_ip} '[ -f /var/log/dokku-installed ]'; do
        echo "Dokku installation not complete yet, waiting..."
        check_logs
        sleep 30
      done
      echo "Dokku installation complete!"

      # Wait for Dokku command to be available
      echo "Waiting for Dokku command to be available..."
      until check_command dokku; do
        echo "Dokku command not available yet, waiting..."
        check_logs
        sleep 10
      done
      echo "Dokku command is available!"

      # Additional wait to ensure Dokku is fully initialized
      echo "Waiting for Dokku to fully initialize..."
      sleep 60

      # Install PostgreSQL plugin
      echo "Installing PostgreSQL plugin..."
      ssh -i "${var.ssh_private_key_path}" -o StrictHostKeyChecking=no -o PasswordAuthentication=no -o PubkeyAuthentication=yes root@${vultr_instance.dokku.main_ip} "
        dokku plugin:install https://github.com/dokku/dokku-postgres.git postgres || true
      "

      # Then configure each app
      %{ for app in var.apps ~}
      echo "Configuring app: ${app.name}"
      ssh -i "${var.ssh_private_key_path}" -o StrictHostKeyChecking=no -o PasswordAuthentication=no -o PubkeyAuthentication=yes root@${vultr_instance.dokku.main_ip} "
        export PATH=\$PATH:/usr/bin:/usr/local/bin
        
        # Create app if it doesn't exist
        dokku apps:create ${app.name} || true
        
        # Generate and add deploy key for the app
        echo 'Generating deploy key for ${app.name}...'
        if [ ! -f /root/.ssh/${app.name}_deploy_key ]; then
          # Generate a new SSH key pair
          ssh-keygen -t ed25519 -C '${app.name}-deploy-key' -f /root/.ssh/${app.name}_deploy_key -N ''
          # Add the public key to Dokku
          dokku ssh-keys:add ${app.name}_deploy_key /root/.ssh/${app.name}_deploy_key.pub
          echo 'Deploy key generated and added for ${app.name}'
          echo '================================================================'
          echo 'Private key for ${app.name} (add this to GitHub Secrets as DOKKU_DEPLOY_KEY):'
          cat /root/.ssh/${app.name}_deploy_key
          echo '================================================================'
        else
          echo 'Deploy key already exists for ${app.name}'
        fi
        
        # Create and link PostgreSQL database
        dokku postgres:create ${app.name}-db || true
        dokku postgres:link ${app.name}-db ${app.name}
        
        # Configure global hostname
        dokku domains:set-global ${var.hostname}
        
        # Configure domains
        dokku domains:clear ${app.name}
        dokku domains:clear-global ${app.name}
        dokku domains:add ${app.name} ${app.domain}
        
        # Configure proxy and ports
        dokku proxy:enable ${app.name}
        dokku ports:set ${app.name} http:80:5000
        dokku proxy:build-config ${app.name}
        
        # Configure nginx
        dokku nginx:set ${app.name} hsts false
      "
      %{ endfor ~}
    EOT
  }

  # Input values that should trigger a replacement
  input = {
    instance_id = vultr_instance.dokku.id
    apps = var.apps
  }

  # Ensure this runs after the instance is created
  depends_on = [vultr_instance.dokku]
}

# Create a terraform_data resource to configure Let's Encrypt
resource "terraform_data" "dokku_letsencrypt" {
  # Use local-exec to run commands on the remote server
  provisioner "local-exec" {
    command = <<-EOT
      # Enable Let's Encrypt auto-renewal cron job first
      echo "Enabling Let's Encrypt auto-renewal cron job..."
      ssh -i "${var.ssh_private_key_path}" -o StrictHostKeyChecking=no -o PasswordAuthentication=no -o PubkeyAuthentication=yes root@${vultr_instance.dokku.main_ip} "
        export PATH=\$PATH:/usr/bin:/usr/local/bin
        
        # Add cron job for automatic certificate renewal (runs daily at 2am)
        dokku letsencrypt:cron-job --add
        echo 'Auto-renewal cron job enabled'
      "

      # Configure Let's Encrypt for each app
      %{ for app in var.apps ~}
      echo "Configuring Let's Encrypt for app: ${app.name}"
      ssh -i "${var.ssh_private_key_path}" -o StrictHostKeyChecking=no -o PasswordAuthentication=no -o PubkeyAuthentication=yes root@${vultr_instance.dokku.main_ip} "
        export PATH=\$PATH:/usr/bin:/usr/local/bin
        
        # Only proceed if the domain is not empty and is a valid domain
        if [ ! -z '${app.domain}' ] && [[ '${app.domain}' =~ ^[a-zA-Z0-9][a-zA-Z0-9-]+\.[a-zA-Z]{2,}$ ]]; then
          # Remove any hostname-based domains to prevent Let's Encrypt from trying to encrypt them
          dokku domains:remove ${app.name} ${var.hostname}
          dokku domains:remove ${app.name} ${app.name}.${var.hostname}
          
          # Configure Let's Encrypt
          dokku config:set --no-restart ${app.name} DOKKU_LETSENCRYPT_EMAIL=${var.letsencrypt_email}
          dokku letsencrypt:set ${app.name} email ${var.letsencrypt_email}
          
          # Wait for DNS propagation
          echo 'Waiting for DNS propagation for ${app.domain}...'
          while ! host ${app.domain} | grep -q '${vultr_instance.dokku.main_ip}'; do
            echo 'DNS not propagated yet for ${app.domain}, waiting 30 seconds...'
            sleep 30
          done
          echo 'DNS propagated for ${app.domain}'
          
          # Additional wait for DNS cache
          echo 'Waiting an additional minute for DNS caches...'
          sleep 60
          
          # Enable Let's Encrypt
          dokku letsencrypt:enable ${app.name} || {
            echo 'Let'\''s Encrypt failed. Current DNS resolution:'
            host ${app.domain}
            echo 'Expected IP: ${vultr_instance.dokku.main_ip}'
            exit 1
          }
        else
          echo 'Skipping Let'\''s Encrypt for ${app.name} - no valid domain configured'
        fi
      "
      %{ endfor ~}
    EOT
  }

  # Input values that should trigger a replacement
  input = {
    instance_id = vultr_instance.dokku.id
    apps = var.apps
  }

  # Ensure this runs after the apps are created
  depends_on = [terraform_data.dokku_apps]
} 