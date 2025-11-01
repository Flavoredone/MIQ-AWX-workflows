def service
  service_object = $evm.root['service']
  return service_object if service_object
  
  service_id = $evm.root['service_id']
  return nil unless service_id
  
  $evm.vmdb('service').find_by(:id => service_id.to_i)
end

def new_service_name
  $evm.root['service_name']
end

def validate_parameters(service_object, new_name)
  return "Service object is nil" if service_object.nil?
  return "New service name is empty" if new_name.to_s.strip.empty?
  nil
end

def perform_rename(service_object, new_name)
  service_object.name = new_name
  true
end

def handle_success
  $evm.root['ae_result'] = 'ok'
  $evm.root['ae_reason'] = 'Service renamed successfully'
end

def handle_error(message)
  $evm.root['ae_result'] = 'error' 
  $evm.root['ae_reason'] = message
end

def rename_service
  service_object = service
  new_name = new_service_name
  
  error_message = validate_parameters(service_object, new_name)
  return handle_error(error_message) if error_message
  
  perform_rename(service_object, new_name)
  handle_success
end

begin
  rename_service
  exit MIQ_OK
rescue => e
  handle_error("Unexpected error: #{e.message}")
  exit MIQ_ERROR
end