locals {
  metadata = {
    Nested_Router = var.Nested_Router
    Net           = var.Net
    Common        = var.Common
  }
  userdata = {
    Hostname     = var.Nested_Router.Name
    Username     = "routeradmin"
    RouterConfig = templatefile("${path.module}/templates/router_config.tftpl", { Pod = var.Pod, Nested_Router = var.Nested_Router, Net = var.Net })
  }
}
resource "vsphere_virtual_machine" "Router" {
  name             = var.Nested_Router.Name
  guest_id         = "ubuntu64Guest"
  resource_pool_id = data.vsphere_compute_cluster.PhysicalCluster.resource_pool_id
  folder           = vsphere_folder.folder_child.path
  datastore_id     = data.vsphere_datastore.PhysicalDatastore.id

  memory               = 1024
  num_cpus             = 1
  num_cores_per_socket = 1
  scsi_type            = "pvscsi"
  memory_share_level   = var.Nested_Router.DeploymentSetting.Hardware.Memory.Shares
  memory_reservation   = var.Nested_Router.DeploymentSetting.Hardware.Memory.ReserveAllGuestMemory == "True" ? 1024 : 0

  disk {
    label = "disk0"
    size  = 10
  }

  network_interface {
    network_id   = data.vsphere_network.pg_uplink.id
    adapter_type = "vmxnet3"
  }

  network_interface {
    network_id   = vsphere_distributed_port_group.pg_trunk.id
    adapter_type = "vmxnet3"
  }

  cdrom {
    client_device = true
  }

  annotation = <<-EOT
    ${var.Common.Annotation}
    ${var.Deploy.Software.Router.Vendor} ${var.Deploy.Software.Router.Product} ${var.Deploy.Software.Router.Version}
    Username: vyos
    Password: ${var.Common.Password.Nested}
  EOT

  clone {
    template_uuid = data.vsphere_virtual_machine.router_template.id
  }

  extra_config = {
    "guestinfo.metadata.encoding" = "base64"
    "guestinfo.metadata"          = base64encode(templatefile("${path.module}/templates/metadata.tftpl", local.metadata))
    "guestinfo.userdata.encoding" = "base64"
    "guestinfo.userdata"          = base64encode(templatefile("${path.module}/templates/userdata.tftpl", local.userdata))
  }
}