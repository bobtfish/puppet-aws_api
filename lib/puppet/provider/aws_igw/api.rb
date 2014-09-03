require 'puppetx/bobtfish/aws_api'

Puppet::Type.type(:aws_igw).provide(:api, :parent => Puppetx::Bobtfish::Aws_api) do
  include Puppetx::Bobtfish::TaggableProvider

  flushing_resource_methods :read_only => [:vpc]

  find_region_from :aws_vpc, :vpc

  primary_api :ec2, :collection => :internet_gateways

  ensure_from_state(
    true => :present,
    false => :absent,
    &:exists?
  )


  def init_property_hash
    super
    init :vpc, aws_item.vpc.tags['Name'] || aws_item.vpc_id if aws_item.vpc
  end

  def flush_when_ready
    flushing :ensure => :absent do
      aws_item.detach(aws_item.vpc) if aws_item.vpc
      aws_item.delete
      return
    end

    flushing :ensure => :present do
      also_flush :route_to_main
      @property_hash[:aws_item] = collection.create()
      vpc = lookup(:aws_vpc, resource[:vpc]).aws_item
      aws_item.attach(vpc)
    end

    flushing :route_to_main => true do
      aws_item.vpc.route_tables.main_route_table.create_route( '0.0.0.0/0',
        :internet_gateway => aws_item
      )
    end
  end
end

