# Edge node in a customer's Azure subscription. No public IP; reaches us outbound only.
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 4.0, < 5.0"
    }
  }
}

variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "subnet_id" { type = string }
variable "size" {
  type    = string
  default = "Standard_B2s"
}
variable "userdata" { type = any }

resource "azurerm_network_interface" "edge" {
  name                = "${var.userdata.edge_node}-nic"
  resource_group_name = var.resource_group_name
  location            = var.location

  ip_configuration {
    name                          = "internal"
    subnet_id                     = var.subnet_id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "edge" {
  name                            = var.userdata.edge_node
  resource_group_name             = var.resource_group_name
  location                        = var.location
  size                            = var.size
  admin_username                  = "opsadmin"
  disable_password_authentication = true
  network_interface_ids           = [azurerm_network_interface.edge.id]
  custom_data                     = base64encode(var.userdata.user_data)

  admin_ssh_key {
    username   = "opsadmin"
    public_key = var.userdata.first_ssh_key
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
    disk_size_gb         = 40
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }

  lifecycle {
    ignore_changes = [custom_data]
  }
}

output "name" {
  value = azurerm_linux_virtual_machine.edge.name
}
