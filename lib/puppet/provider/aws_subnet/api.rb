require 'puppetx/bobtfish/aws_api'

Puppet::Type.type(:aws_subnet).provide(:api, :parent => Puppetx::Bobtfish::Aws_api) do
  mk_resource_methods

  find_region_from :aws_vpc, :vpc

  primary_api :ec2, :collection => :subnets

  def self.instance_from_aws_item(region, item)
    tags = item.tags.to_h
    name = tags.delete('Name') || item.id
    new(
      :aws_item => item,
      :name     => name,
      :id       => item.id,
      :ensure   => :present,
      :vpc      => item.vpc.tags['Name'] || item.vpc.id,
      :cidr     => item.cidr_block,
      :az       => item.availability_zone_name,
      :tags     => tags.to_hash
    )
  end

  read_only(:vpc, :cidr, :az, :route_table)

  def tags=(value)
    fail "Set tags not implemented yet"
  end
  def create
    vpc = find_vpc_item_by_name(resource[:vpc])

    if resource[:unique_az_in_vpc]
      if resource[:az]
        fail "Can't specify az and use unique_az_in_vpc option for the same aws_subnet resource."
      end
      unused_azs = (ec2.availability_zones.map(&:name) -  vpc.subnets.map(&:availability_zone_name))
      if unused_azs.empty?
        fail "No AZs left in this VPC."
      end
      resource[:az] = unused_azs.first
    end

    subnet = vpc.subnets.create(resource[:cidr],
        :availability_zone => resource[:az]
    )
    wait_until_state subnet, :available
    tag_with_name subnet, resource[:name]
    tags = resource[:tags] || {}
    tags.each { |k,v| subnet.add_tag(k, :value => v) }
    subnet

  end
  def destroy
    @property_hash[:aws_item].delete
    @property_hash[:ensure] = :absent
  end
end

