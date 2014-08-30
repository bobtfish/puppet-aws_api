require 'puppetx/bobtfish/aws_api'

Puppet::Type.type(:aws_cache_cluster).provide(:api, :parent => Puppetx::Bobtfish::Aws_api) do

  flushing_resource_methods :read_only => [
    :cache_node_type,
    :engine,
    :vpc,
    :endpoint
  ]

  find_region_from :aws_subnet, :subnets

  primary_api :elcc

  ensure_from_state(
    :available => :present,
    :creating => :available,
  ) do |aws_item|
    aws_refresh
    aws_item[:cache_cluster_status]
  end

  def self.aws_items_for_region(region)
    api(region).client.describe_cache_clusters(
      :show_cache_node_info => true).data[:cache_clusters]
  end

  def init_property_hash
    super
    map_init(
      :cache_node_type,
      :engine,
      :engine_version,
      :auto_minor_version_upgrade,
      :name => :cache_cluster_id,
    )
    if aws_item[:cache_subnet_group_name]
      vpc = ec2.vpcs[
        elcc.client.describe_cache_subnet_groups(
          :cache_subnet_group_name => aws_item[:cache_subnet_group_name]
        ).data[:cache_subnet_groups].first[:vpc_id]
      ]
      init :vpc_item, vpc
      init :vpc, vpc.tags['Name']
    end

    endpoint = if aws_item[:engine] == 'redis'
      if aws_item[:cache_nodes] and aws_item[:cache_nodes].first[:endpoint]
        "#{aws_item[:cache_nodes].first[:endpoint][:address]}:#{aws_item[:cache_nodes].first[:endpoint][:port]}"
      end
    else # memcached
      if aws_item[:configuration_endpoint]
        "#{aws_item[:configuration_endpoint][:address]}:#{aws_item[:configuration_endpoint][:port]}"
      end
    end

    init :endpoint, endpoint

    init :security_groups, aws_item[:security_groups].collect{ |sg|
      ec2.security_groups[sg[:security_group_id]].name
    }

  end

  def flush_when_ready
    flushing :ensure => :absent do
      api.client.delete_cache_cluster(
        :cache_cluster_id => resource[:name]
      )

      wait_until do
        self.class.get_ensure_state(aws_item) == :absent
      end
      self.wait_for_state_transitions

      api.client.delete_cache_subnet_group(
        :cache_subnet_group_name => "#{resource[:name]}-sng"
      )
      return
    end

    flushing :ensure => :create do
      subnets = lookup(:aws_vpc, resource[:vpc]).subnets

      if subnets.none?
        # TODO: move to type validation
        raise "Aws_vpc[#{resource[:vpc]}] given for Aws_cache_cluster[#{resource[:name]}] must have at least one subnet."
      end

      security_groups = resource[:security_groups].collect do |sg|
        lookup(:aws_security_group, sg).id
      end

      region = subnets.first.availability_zone.region_name

      sng_name = "#{resource[:name]}-sng"

      api.client.create_cache_subnet_group(
        :cache_subnet_group_name => sng_name,
        :cache_subnet_group_description => "Generated for #{resource[:name]}",
        :subnet_ids => subnets.map(&:id)
      )

      @property_hash[:aws_item] = api.client.create_cache_cluster(
        :cache_cluster_id           => resource[:name],
        :num_cache_nodes            => 1, # only valid option for for redis
        :cache_node_type            => resource[:cache_node_type],
        :engine                     => resource[:engine].to_s,
        :engine_version             => resource[:engine_version],
        :cache_subnet_group_name    => sng_name,
        :security_group_ids         => security_groups,
        :auto_minor_version_upgrade => resource[:auto_minor_version_upgrade],
      )
      # We just flushed these:
      @property_flush.delete(:security_groups)
      @property_flush.delete(:engine_version)
      @property_flush.delete(:auto_minor_version_upgrade)
    end

    flushing :security_groups, :engine_version, :auto_minor_version_upgrade do |sgs, ev, amvu|
      client.modify_cache_cluster(
        :cache_cluster_id => resource[:name],
        :apply_immediately => true,
        :security_groups => sgs.collect { |sg| lookup(:aws_security_group, sg).aws_item.id },
        :engine_version => ev,
        :auto_minor_version_upgrade => amvu
      )
    end


  end


  def substitutions
    {
      :cname => aws_item[:configuration_endpoint][:address],
      :port => aws_item[:configuration_endpoint][:port],
    }
  end

  def aws_refresh
    @property_hash[:aws_item] = api.client.describe_cache_clusters(
      :cache_cluster_id => aws_item[:cache_cluster_id],
      :show_cache_node_info => true,
    ).data[:cache_clusters][0]
  end

  def vpc_item
    @property_hash[:vpc_item]
  end



end

