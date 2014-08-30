require 'puppetx/bobtfish/aws_api'

Puppet::Type.type(:aws_subnet).provide(:api, :parent => Puppetx::Bobtfish::Aws_api) do
  include Puppetx::Bobtfish::TaggableProvider

  flushing_resource_methods :read_only => [
    :vpc, :cidr, :az, :route_table
  ]

  find_region_from :aws_vpc, :vpc

  primary_api :ec2, :collection => :subnets

  ensure_from_state(
    :available => :present,
    :pending => :present,
    &:state
  )

  def init_property_hash
    super
    map_init(
      :cidr => :cidr_block,
      :az => :availability_zone_name
    )
    init :vpc, aws_item.vpc.tags['Name']
  end

  def flush_when_ready
    flushing :ensure => :present do
      vpc = lookup(:aws_vpc, resource[:vpc]).aws_item

      az = if resource[:unique_az_in_vpc]
        unused_azs = (
          ec2.availability_zones.map(&:name) -  vpc.subnets.map(&:availability_zone_name)
        )
        if unused_azs.empty?
          fail "No unused AZs left in VPC #{resource[:vpc]} for unique_az_in_vpc option..."
        else
          unused_azs.first
        end
      else
        resource[:az]
      end

      collection.create(resource[:cidr],
        :availability_zone => az,
        :vpc => vpc
      )
    end
    super
  end

end

