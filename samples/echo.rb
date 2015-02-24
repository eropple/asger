# Just logs the instances being created and destroyed to the logger for testing.

up do |instance, parameters|
  logger.info "upping instance: #{instance}"
end

down do |instance_id, parameters|
  logger.info "downing instance: #{instance_id}"
end