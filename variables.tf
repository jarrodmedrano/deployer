variable "vultr_api_key" {
  description = "Vultr API key"
  type        = string
  sensitive   = true
}

variable "instance_plan" {
  description = "Vultr instance plan (e.g., 'vc2-1c-1gb')"
  type        = string
  default     = "vc2-1c-1gb"
}

variable "region" {
  description = "Vultr region (e.g., 'lax')"
  type        = string
  default     = "lax"
}

variable "os_id" {
  description = "Vultr OS ID for Ubuntu 22.04"
  type        = number
  default     = 387
}

variable "instance_label" {
  description = "Label for the Vultr instance"
  type        = string
  default     = "dokku-server"
}

variable "hostname" {
  description = "Hostname for the Vultr instance"
  type        = string
  default     = "dokku"
}

variable "ssh_public_key" {
  description = "SSH public key for instance access"
  type        = string
}

variable "ssh_private_key_path" {
  description = "Path to the SSH private key file"
  type        = string
}

variable "letsencrypt_email" {
  description = "Email address for Let's Encrypt SSL certificates"
  type        = string
}

variable "apps" {
  description = "List of apps to create in Dokku with their domains"
  type = list(object({
    name   = string
    domain = string
  }))
  default = []
}