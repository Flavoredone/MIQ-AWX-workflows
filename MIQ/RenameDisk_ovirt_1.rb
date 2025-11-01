require 'ovirtsdk4'

def vm
  $evm.vmdb('vm').find_by(id: $evm.root['vm_id'].to_i)
end

def provider
  vm.ext_management_system
end

def ovirt_connection
  OvirtSDK4::Connection.new(
    url: "https://#{provider.hostname}/ovirt-engine/api",
    username: provider.authentication_userid,
    password: provider.authentication_password,
    insecure: true)
end

def ovirt_vm_service
  ovirt_connection.system_service.vms_service.vm_service(vm.uid_ems)
end

def disks_service
  ovirt_connection.system_service.disks_service
end

def rename_disk(disk_id, new_name)
  disk_service = disks_service.disk_service(disk_id)
  current_disk = disk_service.get
  disk_service.update(OvirtSDK4::Disk.new(name: new_name))
end

########

disk_attachments = ovirt_vm_service.disk_attachments_service.list

disk_attachments.each_with_index do |disk_attachment, index|
  disk_id = disk_attachment.id
  disk_name = disk_attachment.disk.name
  new_name = "#{$evm.root['disk_name']}_Disk#{index + 1}"
  rename_disk(disk_id, new_name)
end