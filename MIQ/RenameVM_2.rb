require 'ovirtsdk4'

def vm
  vm_id = $evm.root['vm_id'] || ($evm.root.attributes['parameters'] && $evm.root.attributes['parameters']['vm_id'])
  return nil if vm_id.to_s.empty?
  
  $evm.vmdb('vm').find_by(:id => vm_id.to_i)
end

def provider
  vm_obj = vm
  vm_obj ? vm_obj.ext_management_system : nil
end

def new_vm_name
  vm_name = $evm.root['vm_name'] || ($evm.root.attributes['parameters'] && $evm.root.attributes['parameters']['vm_name'])
  vm_name.to_s.empty? ? 'unknown_new_name' : vm_name
end

def rename_vm
  vm_object = vm
  return false if vm_object.nil?
  
  case vm_object.vendor
  when 'vmware' then rename_vmware_vm(vm_object, new_vm_name)
  when 'ovirt' then rename_ovirt_vm(vm_object, new_vm_name)
  else false
  end
end

def rename_ovirt_vm(vm_object, new_name)
  provider = vm_object.ext_management_system
  return false if provider.nil?
  
  begin
    connection = OvirtSDK4::Connection.new(
      url: "https://#{provider.hostname}/ovirt-engine/api",
      username: provider.authentication_userid,
      password: provider.authentication_password,
      insecure: true
    )
    
    vm_service = connection.system_service.vms_service.vm_service(vm_object.uid_ems)
    vm_service.update(OvirtSDK4::Vm.new(name: new_name))
    true
  rescue
    false
  ensure
    connection.close if connection
  end
end

def rename_vmware_vm(vm_object, new_name)
  begin
    return true if vm_object.rename(new_name)
    
    vm_real = $evm.vmdb('vm').find_by(:id => vm_object.id)
    vm_real.update_attributes(:name => new_name) if vm_real
    true
  rescue
    false
  end
end

begin
  result = rename_vm
  
  if result
    $evm.set_state_var('result', 'success')
    $evm.set_state_var('message', "VM renamed to: #{new_vm_name}")
  else
    $evm.set_state_var('result', 'error')
    $evm.set_state_var('message', 'Failed to rename VM')
  end
rescue => e
  $evm.set_state_var('result', 'error')
  $evm.set_state_var('message', "Unexpected error: #{e.message}")
end