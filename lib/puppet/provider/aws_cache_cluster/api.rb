require 'puppetx/bobtfish/aws_api'

Puppet::Type.type(:aws_cache_cluster).provide(:api, :parent => Puppetx::Bobtfish::Aws_api) do

  flushing_resource_methods :read_only => [
    :cache_node_type,
    :engine,
    :endpoint
  ]

  find_region_from :aws_subnet, :subnets

  primary_api :elcc

  ensure_from_state(
    :available => :present,
    :creating => :available,
  ) do |aws_item|
    aws_refresh(aws_item)[:cache_cluster_status]
  end

  def self.aws_items_for_region(region)
    # We have to add _region data so we know what API to query during refresh
     api(region).client.describe_cache_clusters(
      :show_cache_node_info => true).data[:cache_clusters].collect do |cluster|
        cluster[:_region] = region
        cluster
      end
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
      init :subnets, elcc.client.describe_cache_subnet_groups(
        :cache_subnet_group_name => aws_item[:cache_subnet_group_name]
      ).data[:cache_subnet_groups][0][:subnets].collect { |sn|
        sn_item = ec2.subnets[sn[:subnet_identifier]]
        (sn_item.tags['Name'] || sn_item.subnet_id)
      }
    end

    init :endpoint, "#{endpoint[:address]}:#{endpoint[:port]}"

    init :security_groups, aws_item[:security_groups].collect{ |sg|
      sg_item = ec2.security_groups[sg[:security_group_id]]
      "#{sg_item.vpc.tags['Name'] || sg_item.vpc_id}:#{sg_item.name}"
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
        :cache_subnet_group_name => resource[:name]
      )
      return
    end

    sng_opts = {
      :cache_subnet_group_name => resource[:name],
      :cache_subnet_group_description => "Generated for #{resource[:name]}",
      :subnet_ids => resource[:subnets].collect {|sn|
        lookup(:aws_subnet, sn).aws_item.id
      }
    }

    security_groups = resource[:security_groups].collect do |sg|
      lookup(:aws_security_group, sg).aws_item.id
    end

    flushing :ensure => :present do

      api.client.create_cache_subnet_group(sng_opts)

      elcc_conf = {
        :cache_cluster_id           => resource[:name],
        :num_cache_nodes            => 1, # only valid option for for redis
        :cache_node_type            => resource[:cache_node_type],
        :engine                     => resource[:engine].to_s,
        :cache_subnet_group_name    => resource[:name],
        :security_group_ids         => security_groups,
        :auto_minor_version_upgrade => !!resource[:auto_minor_version_upgrade],
      }
      if resource[:engine_version]
        elcc_conf[:engine_version] = resource[:engine_version]
      end
      api.client.create_cache_cluster(elcc_conf)
    end

    flushing :subnets do |subnets|
      api.client.modify_cache_subnet_group(sng_opts)
    end

    flushing :security_groups, :engine_version, :auto_minor_version_upgrade do |sgs, ev, amvu|
      client.modify_cache_cluster(
        :cache_cluster_id => resource[:name],
        :apply_immediately => true,
        :security_groups => security_groups,
        :engine_version => ev,
        :auto_minor_version_upgrade => amvu,
      )
    end
  end


  def substitutions
    {
      :cname => endpoint[:address],
      :port => endpoint[:port],
    }
  end

  def endpoint
    if aws_item[:engine] == 'redis'
      aws_item[:cache_nodes].first[:endpoint]
    else
      # memcached
      aws_item[:configuration_endpoint]
    end
  end

  def self.aws_refresh(aws_item)
    api(aws_item[:_region]).client.describe_cache_clusters(
       :cache_cluster_id => aws_item[:cache_cluster_id],
       :show_cache_node_info => true,
     ).data[:cache_clusters][0]
  end

  def aws_refresh
    @property_hash[:aws_item] = self.class.aws_refresh(aws_item)
  end


end

