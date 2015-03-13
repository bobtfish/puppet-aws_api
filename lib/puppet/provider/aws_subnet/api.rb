require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', '..', 'puppet_x', 'bobtfish', 'ec2_api.rb'))

# FIXME
class AWS::EC2::SubnetCollection
  def create cidr_block, options = {}
    client_opts = {}
    client_opts[:vpc_id] = vpc_id_option(options)
    client_opts[:cidr_block] = cidr_block
    client_opts[:availability_zone] = az_option(options) if
      options[:availability_zone]

    resp = client.create_subnet(client_opts)
    resp[:subnet][:subnet_id]
  end
end

Puppet::Type.type(:aws_subnet).provide(:api, :parent => Puppet_X::Bobtfish::Ec2_api) do
  mk_resource_methods
  remove_method :tags= # We want the method inherited from the parent
  read_only(:vpc, :cidr, :az, :route_table)

  def self.new_from_aws(region_name, item, tags=nil)
    tags ||= item.tags
    tags = tags.to_h if tags
    name = tags.delete('Name') || item.id

    new(
      :aws_item => item,
      :name     => name,
      :id       => item.id,
      :ensure   => :present,
      :vpc      => name_or_id(find_vpc_item_by_name(item.pre_vpc_id)),
      :cidr     => item.cidr_block,
      :az       => item.availability_zone_name,
      :tags     => tags)
  end

  def self.instances_class; AWS::EC2::Subnet; end

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

    # FIXME
    subnet_id = vpc.subnets.create(resource[:cidr], :availability_zone => resource[:az], :vpc => vpc)
    sleep 2
    subnet = find_vpc_item_by_name(resource[:vpc]).subnets[subnet_id]
    # END FIXME
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
