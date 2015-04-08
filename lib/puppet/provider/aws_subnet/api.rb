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
  read_only(:vpc, :cidr, :az)

  def self.new_from_aws(region_name, item, tags=nil)
    tags ||= item.tags
    tags = tags.to_h if tags
    name = tags.delete('Name') || item.id

    new(
      :aws_item    => item,
      :name        => name,
      :id          => item.id,
      :ensure      => :present,
      :vpc         => lookup(:aws_vpc, item.pre_vpc_id).name,
      :cidr        => item.cidr_block,
      :az          => item.availability_zone_name,
      :tags        => tags,
      :route_table => lookup(:aws_routetable, item.route_table.id).name,
      :auto_assign_ip => item.pre_map_public_ip_on_launch.to_s.to_sym )
  end

  def self.instances_class; AWS::EC2::Subnet; end

  def route_table=(value)
    # fuck puppet for not having nils
    if value && "#{value}" !~ /undef/
      @property_hash[:aws_item].route_table =
        lookup(:aws_routetable, value).aws_item
    end
  end

  def auto_assign_ip=(value)
    auto_assign_ip!(@property_hash[:aws_item], value == :true)
  end

  def auto_assign_ip!(subnet, value)
    # UGLY HACK TIME
    client = subnet.client.clone
    def client.build_request(*args)
      super.tap {|r| r.body.gsub!(/Version=[0-9\-]+/, 'Version=2014-06-15')}
    end

    client.modify_subnet_attribute(
      :subnet_id => subnet.id, :map_public_ip_on_launch => { :value => value } )
  end

  def create
    vpc = find_vpc_item_by_name(resource[:vpc])

    if resource[:unique_az_in_vpc]
      raise "Can't specify az and use unique_az_in_vpc option for the same aws_subnet resource." if resource[:az]

      unused_azs = (ec2.availability_zones.map(&:name) -  vpc.subnets.map(&:availability_zone_name))
      raise "No AZs left in this VPC." if unused_azs.empty?

      resource[:az] = unused_azs.first
    end

    subnet_id = vpc.subnets.create(resource[:cidr], :availability_zone => resource[:az], :vpc => vpc)
    subnet    = vpc.subnets[subnet_id]
    wait_until_state subnet, :available

    subnet.tags.set((resource[:tags] || {}).merge('Name' => resource[:name]))

    if resource[:route_table] && "#{resource[:route_table]}" !~ /undef/
      subnet.route_table = lookup(:aws_routetable, resource[:route_table]).aws_item
    end

    unless resource[:auto_assign_ip].nil?
      auto_assign_ip!(subnet, resource[:auto_assign_ip] == :true)
    end

    subnet
  rescue Exception => e
    fail e.inspect
  end

  def destroy
    @property_hash[:aws_item].delete
    @property_hash[:ensure] = :absent
  end
end
