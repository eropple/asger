# This script will deregister a node from the Chef server given in the parameters files.
# It will perform a Chef search for an 'instance_id' tag that matches the instance ID
# provided by the AWS notification. To tag a node with the instance_id from bash, do
# something like this on-node (probably in cloud-init):
#
# ```bash
# knife tag create -c /path/to/client.rb $NODE_NAME $INSTANCE_ID
# ```
#
# Which, in our naming scheme at Leaf, becomes:
#
# ```bash
# knife tag create -c /etc/chef/client.rb vpn.test-cloud.infra.06f1d39c i-06f1d39c
# ```
#
# PARAMETERS:
#
# chef_deregister.knife_config: the path to the knife config to use for search/node delete

require 'json'

sanity_check do |parameters|
  knife_config = parameters[:chef_deregister][:knife_config]
  raise "parameters[:chef_deregister][:knife_config] is not set" unless knife_config

  raise "file '#{knife_config}' does not exist" unless File.exist?(knife_config)
end

down do |instance_id, asg, parameters|
  knife_config = parameters[:chef_deregister][:knife_config]

  search_result = Asger::Util::run_command("knife search: #{instance_id}",
                                           "knife search node -c '#{knife_config}' -i -F json 'tags:#{instance_id}'",
                                          logger)

  raise "knife search for '#{instance_id}' failed with exit code #{search_result[0]}." unless search_result[0] == 0

  search_json = JSON.parse(search_result[1])

  case search_json["rows"].length
  when 0
    logger.warn "No Chef entry found for instance '#{instance_id}'."
    logger.warn "Make sure the instance was Chef-tagged and came up successfully."
  when 1
    node_name = search_json["rows"][0]
    delete_node_result = Asger::Util::run_command("knife node delete: #{node_name}",
                                                  "knife node delete -y -c '#{knife_config}' #{node_name}",
                                                  logger)
    raise "knife node delete for '#{instance_id}' failed with exit code #{search_result[0]}." unless delete_node_result[0] == 0
    delete_client_result = Asger::Util::run_command("knife client delete: #{node_name}",
                                                    "knife client delete -y -c '#{knife_config}' #{node_name}",
                                                    logger)

    raise "knife client delete for '#{instance_id}' failed with exit code #{search_result[0]}." unless delete_client_result[0] == 0
  else
    logger.error "#{search_json["rows"].length} entries found in Chef for '#{instance_id}."
    logger.error "I don't know what to safely do; you should handle this yourself."
  end

  logger.info "Removed instance '#{instance_id}' from Chef."
end