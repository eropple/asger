# Just logs the instances being created and destroyed to the logger for testing.

up do |instance, asg, parameters|
  logger.info "echo - upping instance in '#{asg.name}': #{instance}"
end

up_failed do |asg, parameters|
  logger.warn "echo - failed to up instance in '#{asg.name}'"
end

down do |instance_id, asg, parameters|
  logger.info "echo - downing instance in '#{asg.name}': #{instance_id}"
end

down_failed do |instance_id, asg, parameters|
  logger.warn "echo - failed to down instance in '#{asg.name}': #{instance_id}"
end
