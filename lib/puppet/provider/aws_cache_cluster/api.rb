require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', '..', 'puppet_x', 'bobtfish', 'ec2_api.rb'))

Puppet::Type.type(:aws_cache_cluster).provide(:api, :parent => Puppet_X::Bobtfish::Ec2_api) do
  mk_resource_methods
  remove_method :tags= # We want the method inherited from the parent
  def self.instances_for_region(region)
    elcc(region).client.describe_cache_clusters(
      :show_cache_node_info => true).data[:cache_clusters]
  end
  def instances_for_region(region)
    self.class.instances_for_region region
  end
  def self.new_from_aws(region_name, item)
    status = case item[:cache_cluster_status]
    when 'available'
      :present
    else
      :absent
    end

    security_groups = item[:security_groups].collect do |sg|
      ec2.regions[region_name].security_groups[sg[:security_group_id]].name
    end

    endpoint = if item[:engine] == 'redis'
      if item[:cache_nodes] and item[:cache_nodes].first[:endpoint]
        "#{item[:cache_nodes].first[:endpoint][:address]}:#{item[:cache_nodes].first[:endpoint][:port]}"
      end
    else # memcached
      if item[:configuration_endpoint]
        "#{item[:configuration_endpoint][:address]}:#{item[:configuration_endpoint][:port]}"
      end
    end

    vpc = if item[:cache_subnet_group_name]
      ec2.regions[region_name].vpcs[
        elcc(region_name).client.describe_cache_subnet_groups(
          :cache_subnet_group_name => item[:cache_subnet_group_name]
        ).data[:cache_subnet_groups].first[:vpc_id]
      ]
    end

    new(
      :aws_item         => item,
      :vpc_item         => vpc,
      :name             => item[:cache_cluster_id],
      :ensure           => status,
      :cache_node_type  => item[:cache_node_type],
      :engine           => item[:engine],
      :engine_version   => item[:engine_version],
      :auto_minor_version_upgrade => item[:auto_minor_version_upgrade],
      :endpoint         => endpoint,
      :vpc              => vpc.tags['Name'],
      :security_groups  => security_groups
    )
  end

  def self.instances
    regions.collect do |region_name|
      instances_for_region(region_name).collect { |item|
        new_from_aws(region_name, item)
      }
    end.flatten
  end

  read_only(
    :cache_node_type,
    :engine,
    :vpc,
    :endpoint,
  )

  def security_groups=(sgs)
    update_cluster_property(:security_group_ids, sgs.collect { |sg|
      lookup(:aws_security_group, sg).id
    })
  end

  def engine_version=(version)
    update_cluster_property(:engine_version, version)
  end

  def auto_minor_version_upgrade=(newval)
    update_cluster_property(:auto_minor_version_upgrade, newval)
  end

  def create
    # Can't make VPC optional or we won't know what region we're in
    subnets = lookup(:aws_vpc, resource[:vpc]).subnets

    if subnets.none?
      raise "Aws_vpc[#{resource[:vpc]}] given for Aws_cache_cluster[#{resource[:name]}] must have at least one subnet."
    end

    security_groups = resource[:security_groups].collect do |sg|
      lookup(:aws_security_group, sg).id
    end

    region = subnets.first.availability_zone.region_name

    sng_name = "#{resource[:name]}-sng"

    elcc(region).client.create_cache_subnet_group(
      :cache_subnet_group_name => sng_name,
      :cache_subnet_group_description => "Generated for #{resource[:name]}",
      :subnet_ids => subnets.map(&:id)
    )

    elcc(region).client.create_cache_cluster(
      :cache_cluster_id           => resource[:name],
      :num_cache_nodes            => 1, # only valid option for for redis
      :cache_node_type            => resource[:cache_node_type],
      :engine                     => resource[:engine].to_s,
      :engine_version             => resource[:engine_version],
      :cache_subnet_group_name    => sng_name,
      :security_group_ids         => security_groups,
      :auto_minor_version_upgrade => resource[:auto_minor_version_upgrade],
    )
  end
  def destroy
    client.delete_cache_cluster(
      :cache_cluster_id => @property_hash[:name]
    )
    # TODO: wait
    client.delete_cache_subnet_group(
      :cache_subnet_group_name => "#{@property_hash[:name]}-sng"
    )
    @property_hash[:ensure] = :absent
  end

  private

  def client
    elcc(
      @property_hash[:vpc_item].subnets.first.availability_zone.region_name
    ).client
  end

  def update_cluster_property(property, value, apply_immediately=true)
    client.modify_cache_cluster(
      :cache_cluster_id => @property_hash[:name],
      :apply_immediately => apply_immediately,
      property => value
    )
  end
end

