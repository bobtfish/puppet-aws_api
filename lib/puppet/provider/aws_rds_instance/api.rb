require 'puppetx/bobtfish/aws_api'

Puppet::Type.type(:aws_rds_instance).provide(:api, :parent => Puppetx::Bobtfish::Aws_api) do

  flushing_resource_methods :read_only => [
    :region, :db_instance_class, :engine, :engine_version, :master_username, :multi_az, :endpoint]

  find_region_from :aws_subnet, :subnets

  primary_api :rds, :collection => :db_instances

  ensure_from_state(
    :available => :present,
    :'backing-up' => :available,
    :creating => :available,
    :deleted => :absent,
    :deleting => :deleted,
    :failed => :absent,
    :'incompatible-restor' => :absent,
    :modifying => :available,
    :rebooting => :available,
    :'resetting-master-credentials' => :available,
    :'storage-full' => :absent,
    &:db_instance_status
  )

  def init_property_hash
    super
    map_init(
      :db_instance_class,
      :engine,
      :engine_version,
      :master_username,
      :allocated_storage,
      :multi_az,
      :name => :db_instance_identifier,
    )

    if aws_item.endpoint_address
      init :endpoint, "#{aws_item.endpoint_address}:#{aws_item.endpoint_port}"
    end

    if aws_item.vpc_security_groups
      init :security_groups, aws_item.vpc_security_groups.collect{ |sg|
        "#{aws_item.vpc.tags['Name']}:#{sg.name}"
      }
    end
    if aws_item.db_subnet_group
      init :subnets, aws_item.db_subnet_group.subnets.collect{ |sn|
        sn.tags['Name']
      }
    end

  end

  def flush_when_ready
    flushing :ensure => :absent do
      rds.client.delete_db_subnet_group(:db_subnet_group_name => resource[:name])
      rds.client.delete_db_instance(:db_instance_identifier => resource[:name])
      return
    end

    sn_group_opts = {
      :db_subnet_group_name => resource[:name],
      :db_subnet_group_description => "Subnet(s) for #{resource[:name]}: #{resource[:subnets].join(', ')}",
      :subnet_ids => resource[:subnets].collect do |sn|
        lookup(:aws_subnet, sn).aws_item.id
      end
    }
    security_groups = resource[:security_groups].collect do |sg|
      lookup(:aws_security_group, sg).id
    end

    flushing :ensure => :present do
      rds.client.create_db_subnet_group(sn_group_opts)
      rds_conf = {
        :db_name            => resource[:name].gsub('-', '_'),
        :allocated_storage  => resource[:allocated_storage].to_i,
        :db_instance_class  => resource[:db_instance_class],
        :engine             => resource[:engine].to_s,
        :master_username    => resource[:master_username],
        :master_user_password => resource[:master_user_password],
        :multi_az           => resource[:multi_az] || false,
        :vpc_security_group_ids => security_groups,
        :db_subnet_group_name => resource[:name],
      }
      if resource[:engine_version]
        rds_conf[:engine_version ] = resource[:engine_version]
      end
      collection.create(resource[:name], rds_conf)
    end


    flushing :subnets do |subnets|
      rds.client.modify_db_subnet_group(sn_group_opts)
    end

    flushing :security_groups do |sgs|
      aws_item.modify(:vpc_security_group_ids => security_groups)
    end
  end

  def substitutions
    {
      :cname => aws_item.endpoint_address,
      :port => aws_item.endpoint_port,
    }
  end
end

