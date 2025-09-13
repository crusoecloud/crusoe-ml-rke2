terraform {
  required_providers {
    crusoe = {
      source = "crusoecloud/crusoe"
    }
  }
}

locals {
  use_lb            = var.headnode_count > 1 ? true:false
  haproxy_config     = !local.use_lb ? "" : <<-EOT
    global
        log /dev/log local0
        log /dev/log local1 notice
        chroot /var/lib/haproxy
        stats socket /run/haproxy/admin.sock mode 660 level admin expose-fd listeners
        stats timeout 30s
        user haproxy
        group haproxy
        daemon

    defaults
        log global
        mode tcp
        timeout connect 5000
        timeout client 50000
        timeout server 50000

    frontend rke_apiserver
        bind *:6443
        mode tcp
        default_backend rke_nodes

    frontend rke_nodereg
        bind *:9345
        mode tcp
        default_backend rke_mgmt_nodes

    backend rke_nodes
        mode tcp
        balance roundrobin
        %{~ for index, instance in crusoe_compute_instance.rke_headnode ~}
        server rke_node${index} ${instance.network_interfaces[0].private_ipv4.address}:6443 check
        %{~ endfor ~}
    
    backend rke_mgmt_nodes
        mode tcp
        balance roundrobin
        %{~ for index, instance in crusoe_compute_instance.rke_headnode ~}
        server rke_node${index} ${instance.network_interfaces[0].private_ipv4.address}:9345 check
        %{~ endfor ~}
    EOT
  headnode_entry    = local.use_lb ? one(crusoe_compute_instance.rke_lb) : one(crusoe_compute_instance.rke_headnode)
  ingress_interface = local.headnode_entry.network_interfaces[0]
  headnode_has_ib  = strcontains(lower(var.headnode_instance_type), "sxm-ib")
  worker_has_ib = strcontains(lower(var.worker_instance_type), "sxm-ib")
}


resource "crusoe_compute_instance" "rke_lb" {
  count          = local.use_lb ? 1 : 0
  name           = "${var.instance_name_prefix}-rke-lb"
  type           = var.headnode_instance_type
  ssh_key        = var.ssh_pubkey
  location       = var.deploy_location
  image          = var.headnode_image
  startup_script = file("${path.module}/rkehaproxy-install.sh")

  provisioner "file" {
    content     = local.haproxy_config
    destination = "/tmp/haproxy.cfg"
    connection {
      type        = "ssh"
      user        = "root"
      host        = self.network_interfaces[0].public_ipv4.address
      private_key = file("${var.ssh_privkey_path}")
    }
  }
}

resource "crusoe_compute_instance" "rke_headnode" {
  count    = var.headnode_count
  name     = "${var.instance_name_prefix}-rke-${count.index}"
  type     = var.headnode_instance_type
  ssh_key  = var.ssh_pubkey
  location = var.deploy_location
  image    = var.headnode_image
  startup_script = templatefile("${path.module}/rkeinstall-headnode.sh.tftpl",
    {
      is_main_headnode = count.index == 0
      headnode_has_ib = local.headnode_has_ib
      enable_dra_feature = var.enable_dra_feature
    }
  )
  host_channel_adapters = local.headnode_has_ib ? [{ ib_partition_id = var.ib_partition_id }] : null


  provisioner "file" {
    source      = "${path.module}/rke-0-serve-token.py"
    destination = "/opt/rke-0-serve-token.py"
    connection {
      type        = "ssh"
      user        = "root"
      host        = self.network_interfaces[0].public_ipv4.address
      private_key = file("${var.ssh_privkey_path}")
    }
  }
}

resource "terraform_data" "copy-rke-files" {
  depends_on = [local.headnode_entry]
  count      = var.headnode_count
  provisioner "file" {
    content     = jsonencode(crusoe_compute_instance.rke_headnode[0])
    destination = "/root/rke-0-main.json"
    connection {
      type        = "ssh"
      user        = "root"
      host        = crusoe_compute_instance.rke_headnode[count.index].network_interfaces[0].public_ipv4.address
      private_key = file("${var.ssh_privkey_path}")
    }
  }
  provisioner "file" {
    content     = jsonencode(local.headnode_entry)
    destination = "/root/rke-lb-main.json"
    connection {
      type        = "ssh"
      user        = "root"
      host        = crusoe_compute_instance.rke_headnode[count.index].network_interfaces[0].public_ipv4.address
      private_key = file("${var.ssh_privkey_path}")
    }
  }

}

resource "crusoe_compute_instance" "workers" {
  depends_on            = [local.headnode_entry]
  count                 = var.worker_count
  name                  = "${var.instance_name_prefix}-rke-worker-${count.index}"
  type                  = var.worker_instance_type
  ssh_key               = var.ssh_pubkey
  location              = var.deploy_location
  image                 = var.worker_image
  startup_script        = templatefile("${path.module}/rkeinstall-worker-wrapper.sh.tftpl", {
  enable_dra_feature    = var.enable_dra_feature
  worker_script         = file("${path.module}/rkeinstall-worker.sh")
  })
  host_channel_adapters = local.worker_has_ib ? [{ ib_partition_id = var.ib_partition_id }] : null
  provisioner "file" {
    content     = jsonencode(crusoe_compute_instance.rke_headnode[0])
    destination = "/root/rke-0-main.json"
    connection {
      type        = "ssh"
      user        = "root"
      host        = self.network_interfaces[0].public_ipv4.address
      private_key = file("${var.ssh_privkey_path}")
    }
  }

  provisioner "file" {
    content     = jsonencode(local.headnode_entry)
    destination = "/root/rke-lb-main.json"
    connection {
      type        = "ssh"
      user        = "root"
      host        = self.network_interfaces[0].public_ipv4.address
      private_key = file("${var.ssh_privkey_path}")
    }
  }
}

resource "crusoe_vpc_firewall_rule" "rke_rule" {
  network           = local.ingress_interface.network
  name              = "rke-pub-access"
  action            = "allow"
  direction         = "ingress"
  protocols         = "tcp"
  source            = "0.0.0.0/0"
  source_ports      = "1-65535"
  destination       = "${local.ingress_interface.private_ipv4.address}/32"
  destination_ports = "6443"
}
