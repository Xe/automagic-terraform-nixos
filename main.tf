terraform {
  backend "s3" {
    bucket = "within-tf-state"
    key    = "prod"
    region = "us-east-1"
  }

  required_providers {
    aws = {
      source = "hashicorp/aws"
    }

    tailscale = {
      source = "tailscale/tailscale"
    }

    scaleway = {
      source = "scaleway/scaleway"
    }
  }
}

provider "scaleway" {
  zone   = "fr-par-1"
  region = "fr-par"
}

variable "project_id" {
  type        = string
  description = "Your Scaleway project ID."
  default     = "2ce6d960-f3ad-44bf-a761-28725662068a"
}

data "aws_route53_zone" "dns" {
  name = "xeserv.us."
}

data "cloudinit_config" "prod" {
  gzip          = false
  base64_encode = false

  part {
    content_type = "text/cloud-config"
    filename     = "nixos-infect.yaml"
    content = sensitive(<<-EOT
#cloud-config
write_files:
- path: /etc/NIXOS_LUSTRATE
  permissions: '0600'
  content: |
    etc/tailscale/authkey
- path: /etc/tailscale/authkey
  permissions: '0600'
  content: "${tailscale_tailnet_key.prod.key}"
- path: /etc/nixos/host.nix
  permissions: '0644'
  content: |
    {pkgs, ...}:
    {
      services.tailscale.enable = true;

      systemd.services.tailscale-autoconnect = {
        description = "Automatic connection to Tailscale";
        after = [ "network-pre.target" "tailscale.service" ];
        wants = [ "network-pre.target" "tailscale.service" ];
        wantedBy = [ "multi-user.target" ];
        serviceConfig.Type = "oneshot";
        path = with pkgs; [ jq tailscale ]
        script = ''
          sleep 2
          status="$(tailscale status -json | jq -r .BackendState)"
          if [ $status = "Running" ]; then # if so, then do nothing
            exit 0
          fi
          tailscale up --authkey $(cat /etc/tailscale/authkey) --ssh
        '';
      };
    }
runcmd:
  - sed -i 's:#.*$::g' /root/.ssh/authorized_keys
  - curl https://raw.githubusercontent.com/elitak/nixos-infect/master/nixos-infect | NIXOS_IMPORT=./host.nix NIX_CHANNEL=nixos-unstable bash 2>&1 | tee /tmp/infect.log
EOT
    )
  }
}

resource "scaleway_instance_ip" "prod" {
  project_id = var.project_id
}

resource "tailscale_tailnet_key" "prod" {
  reusable      = true
  ephemeral     = false
  preauthorized = true
  tags          = ["tag:xe"]
}

resource "scaleway_instance_server" "prod" {
  type        = "DEV1-S"
  image       = "ubuntu_jammy"
  project_id  = var.project_id
  ip_id       = scaleway_instance_ip.prod.id
  enable_ipv6 = true
  cloud_init  = data.cloudinit_config.prod.rendered
  tags        = ["nixos", "http", "https"]

  provisioner "local-exec" {
    command = "${path.module}/assimilate.sh ${self.name} ${self.public_ip}"
  }

  provisioner "local-exec" {
    when    = destroy
    command = "rm -rf ${path.module}/hosts/${self.name}"
  }
}

resource "aws_route53_record" "prod_A" {
  zone_id = data.aws_route53_zone.dns.zone_id
  name    = "prod.xeserv.us."
  type    = "A"
  records = [scaleway_instance_ip.prod.address]
  ttl     = 300
}

resource "aws_route53_record" "prod_AAAA" {
  zone_id = data.aws_route53_zone.dns.zone_id
  name    = "prod.xeserv.us."
  type    = "AAAA"
  records = [scaleway_instance_server.prod.ipv6_address]
  ttl     = 300
}
