require 'ovirtsdk4'

def vm
  vm_id = $evm.root['vm_id'] || $evm.root.attributes.dig('parameters', 'vm_id')
  return nil if vm_id.to_s.empty?
  
  $evm.vmdb('vm').find_by(id: vm_id.to_i)
end

def provider(vm)
  vm&.ext_management_system
end

def new_vm_name
  vm_name = $evm.root['vm_name'] || $evm.root.attributes.dig('parameters', 'vm_name')
  vm_name.to_s.empty? ? 'unknown_new_name' : vm_name
end

def rename_vm
  current_vm = vm
  return false unless current_vm

  vendor_handlers = {
    'vmware' => -> { rename_vmware_vm(current_vm, new_vm_name) },
    'ovirt' => -> { rename_ovirt_vm(current_vm, new_vm_name) }
  }

  handler = vendor_handlers[current_vm.vendor]
  handler ? handler.call : false
end

def rename_ovirt_vm(vm, new_name)
  prov = provider(vm)
  return false unless prov

  connection = OvirtSDK4::Connection.new(
    url: "https://#{prov.hostname}/ovirt-engine/api",
    username: prov.authentication_userid,
    password: prov.authentication_password,
    insecure: true
  )
  
  vm_service = connection.system_service.vms_service.vm_service(vm.uid_ems)
  vm_service.update(OvirtSDK4::Vm.new(name: new_name))
  true
rescue
  false
ensure
  connection&.close
end

def rename_vmware_vm(vm, new_name)
  return true if vm.rename(new_name)
  
  vm_real = $evm.vmdb('vm').find_by(id: vm.id)
  vm_real&.update_attributes(name: new_name)
  true
rescue
  false
end

result = rename_vm

$evm.set_state_var('result', result ? 'success' : 'error')
$evm.set_state_var('message', result ? "VM renamed to: #{new_vm_name}" : 'Failed to rename VM')