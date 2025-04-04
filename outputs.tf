output "instance_ip" {
  description = "The IP address of the Dokku instance"
  value       = vultr_instance.dokku.main_ip
}

output "instance_id" {
  description = "ID of the Vultr instance"
  value       = vultr_instance.dokku.id
}

output "ssh_command" {
  description = "SSH command to connect to the instance"
  value       = "ssh root@${vultr_instance.dokku.main_ip}"
}

output "app_domains" {
  description = "Domains for all created apps"
  value = {
    for app in var.apps : app.name => app.domain
  }
}

output "app_urls" {
  description = "The URLs for each deployed app"
  value = {
    for app in var.apps : app.name => "https://${app.domain}"
  }
}

output "app_deploy_keys" {
  description = "The deploy keys for each app (only shown on first creation)"
  value = {
    for app in var.apps : app.name =>
      try(
        file("/root/.ssh/${app.name}_deploy_key"),
        "Deploy key not available - already created or not accessible"
      )
  }
}