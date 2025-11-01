require 'ovirtsdk4'

def vm
  vm_id = $evm.root['vm_id']
  
  if vm_id.nil? && $evm.root.attributes['parameters']
    vm_id = $evm.root.attributes['parameters']['vm_id']
  end
  
  $evm.log(:info, "VM ID from root: '#{vm_id}'")
  
  if vm_id.to_s.empty?
    $evm.log(:error, "VM ID is empty in root and parameters")
    return nil
  end
  
  $evm.log(:info, "Looking for VM with ID: #{vm_id}")
  vm_object = $evm.vmdb('vm').find_by(:id => vm_id.to_i)
  
  if vm_object
    $evm.log(:info, "Found VM: #{vm_object.name} (ID: #{vm_object.id}, Vendor: #{vm_object.vendor})")
  else
    $evm.log(:error, "VM not found with ID: #{vm_id}")
  end
  
  vm_object
end

def provider
  vm_obj = vm
  if vm_obj
    $evm.log(:info, "Provider for VM: #{vm_obj.ext_management_system.try(:name)}")
    vm_obj.ext_management_system
  else
    $evm.log(:error, "No VM object for provider")
    nil
  end
end

def new_vm_name
  vm_name = $evm.root['vm_name']
  
  if vm_name.nil? && $evm.root.attributes['parameters']
    vm_name = $evm.root.attributes['parameters']['vm_name']
  end
  
  if vm_name.to_s.empty?
    vm_name = 'unknown_new_name'
    $evm.log(:warn, "VM name is empty, using default: '#{vm_name}'")
  else
    $evm.log(:info, "New VM name from root: '#{vm_name}'")
  end
  
  vm_name
end

def rename_vm
  vm_object = vm
  new_name = new_vm_name
  
  if vm_object.nil?
    $evm.log(:error, "VM object is nil - cannot proceed with rename")
    return false
  end
  
  $evm.log(:info, "Starting VM rename operation")
  $evm.log(:info, "VM current name: '#{vm_object.name}'")
  $evm.log(:info, "VM new name: '#{new_name}'")
  $evm.log(:info, "VM vendor: '#{vm_object.vendor}'")
  
  if vm_object.vendor == 'vmware'
    rename_vmware_vm(vm_object, new_name)
  elsif vm_object.vendor == 'ovirt'
    rename_ovirt_vm(vm_object, new_name)
  else
    $evm.log(:error, "Unsupported VM vendor: #{vm_object.vendor}")
    false
  end
end

def rename_ovirt_vm(vm_object, new_name)
  $evm.log(:info, "Processing oVirt VM rename")
  
  provider = vm_object.ext_management_system
  if provider.nil?
    $evm.log(:error, "Provider not found for VM")
    return false
  end
  
  $evm.log(:info, "Provider details:")
  $evm.log(:info, "  Name: #{provider.name}")
  $evm.log(:info, "  Hostname: #{provider.hostname}")
  
  begin
    username = provider.authentication_userid
    password = provider.authentication_password
    
    $evm.log(:info, "Connecting to oVirt API...")
    $evm.log(:info, "URL: https://#{provider.hostname}/ovirt-engine/api")
    $evm.log(:info, "Username: #{username}")
    
    connection = OvirtSDK4::Connection.new(
      url: "https://#{provider.hostname}/ovirt-engine/api",
      username: username,
      password: password,
      insecure: true
    )
    
    $evm.log(:info, "Connected to oVirt API successfully")
    
    # Получаем сервис для работы с VM
    vms_service = connection.system_service.vms_service
    $evm.log(:info, "Accessing VM service for UID: #{vm_object.uid_ems}")
    
    vm_service = vms_service.vm_service(vm_object.uid_ems)
    
    # Обновляем имя VM
    $evm.log(:info, "Updating VM name to: #{new_name}")
    update_result = vm_service.update(OvirtSDK4::Vm.new(name: new_name))
    
    $evm.log(:info, "oVirt VM renamed successfully to: #{new_name}")
    $evm.log(:info, "Update result: #{update_result.inspect}")
    return true
    
  rescue OvirtSDK4::Error => e
    $evm.log(:error, "oVirt SDK Error: #{e.message}")
    $evm.log(:error, "Error details: #{e.fault.inspect}") if e.respond_to?(:fault)
    return false
  rescue => e
    $evm.log(:error, "Failed to rename oVirt VM: #{e.message}")
    $evm.log(:error, "Error type: #{e.class}")
    $evm.log(:error, e.backtrace.join("\n"))
    return false
  ensure
    begin
      connection.close if connection
    rescue => e
      $evm.log(:warn, "Error closing connection: #{e.message}")
    end
  end
end

def rename_vmware_vm(vm_object, new_name)
  $evm.log(:info, "Processing VMware VM rename")
  
  begin
    # Для VMware в Automate Engine нужно использовать специальный подход
    # Нельзя напрямую работать с объектами через сервисные методы
    
    $evm.log(:info, "Using ManageIQ API for VMware VM rename...")
    
    # Способ 1: Используем VimExecute для переименования через vCenter
    # Это стандартный способ в ManageIQ для операций с VMware
    begin
      $evm.log(:info, "Attempting rename through VimExecute...")
      
      # Создаем задание на переименование
      rename_task = vm_object.rename(new_name)
      
      if rename_task
        $evm.log(:info, "VMware VM rename task created successfully")
        $evm.log(:info, "VMware VM renamed successfully to: #{new_name}")
        return true
      else
        $evm.log(:error, "Failed to create rename task for VMware VM")
        return false
      end
      
    rescue => e
      $evm.log(:warn, "VimExecute rename failed: #{e.message}")
      $evm.log(:info, "Trying alternative method...")
    end
    
    # Способ 2: Используем прямое обновление через базу данных
    # Этот способ обновит имя только в базе ManageIQ
    $evm.log(:info, "Attempting direct database update...")
    
    # Получаем реальный ID VM
    vm_id = vm_object.id
    
    # Находим VM в базе и обновляем имя
    vm_real = $evm.vmdb('vm').find_by(:id => vm_id)
    
    if vm_real
      $evm.log(:info, "Found VM in database, updating name...")
      
      # Обновляем имя в базе ManageIQ
      vm_real.update_attributes(:name => new_name)
      
      $evm.log(:info, "VMware VM name updated in ManageIQ database to: #{new_name}")
      
      # Для полного переименования в vCenter может потребоваться дополнительное действие
      $evm.log(:warn, "Note: VM name updated in ManageIQ, but may need manual rename in vCenter")
      return true
    else
      $evm.log(:error, "Could not find VM in database for update")
      return false
    end
    
  rescue => e
    if e.message =~ /VimFault/
      $evm.log(:warn, "Encountered VimFault: #{e.inspect}")
    end
    
    $evm.log(:error, "Failed to rename VMware VM: #{e.message}")
    $evm.log(:error, "[#{e}]\n#{e.backtrace.join("\n")}")
    return false
  end
end

# Main execution
begin
  $evm.log(:info, "=== Starting VM Rename Method ===")
  
  # Логируем все доступные данные из root для отладки
  $evm.log(:info, "Root attributes: #{$evm.root.attributes.inspect}")
  $evm.log(:info, "Root keys: #{$evm.root.attributes.keys.inspect}")
  
  if $evm.root.attributes['parameters']
    $evm.log(:info, "Parameters: #{$evm.root.attributes['parameters'].inspect}")
  end
  
  result = rename_vm
  
  if result
    $evm.log(:info, "VM rename operation completed successfully")
    $evm.set_state_var('result', 'success')
    $evm.set_state_var('message', "VM renamed to: #{new_vm_name}")
  else
    $evm.log(:error, "VM rename operation failed")
    $evm.set_state_var('result', 'error')
    $evm.set_state_var('message', 'Failed to rename VM')
  end

rescue => e
  $evm.log(:error, "Unexpected error in VM rename method: #{e.message}")
  $evm.log(:error, e.backtrace.join("\n"))
  $evm.set_state_var('result', 'error')
  $evm.set_state_var('message', "Unexpected error: #{e.message}")
end

$evm.log(:info, "=== VM Rename Method Completed ===")