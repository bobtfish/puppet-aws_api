require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', '..', 'puppet_x', 'bobtfish', 'ec2_api.rb'))

Puppet::Type.type(:aws_vgw).provide(:api, :parent => Puppet_X::Bobtfish::Ec2_api) do
  mk_resource_methods
  remove_method :tags= # We want the method inherited from the parent

  def self.new_from_aws(region_name, item, tags=nil)
    tags ||= item.tags.to_h
    name = tags.delete('Name') || item.id
    vpc_name = nil
    if item.vpc
      vpc_name = name_or_id item.vpc
    end
    new(
      :aws_item         => item,
      :name             => name,
      :id               => item.id,
      :vpc              => vpc_name,
      :ensure           => :present,
      :tags             => tags,
      :region_name      => region_name
    )
  end

  def self.instances_class; AWS::EC2::VPNGateway; end

  read_only(:region, :vpn_type, :region_name, :availability_zone)

  def vpc=(name)
    vgw = @property_hash[:aws_item]
    vgw.attach(find_vpc_item_by_name(name))
    wait_until_state(nil, :attached, 300) { vgw.attachments.first.state }
  end

  def create
    raise "Must have a vpc" unless resource[:vpc]

    region_name = find_region_name_for_vpc_name resource[:vpc]
    raise "Cannot find VPC #{resource[:vpc]}" unless region_name

    region = ec2.regions[region_name]

    if resource[:availability_zone]
      azs = region.availability_zones
      az  = azs.find { |az| az.to_s == resource[:availability_zone] }

      raise("Cannot find az '#{resource[:availability_zone]}', " <<
            "need to choose.com: #{azs.to_a.join(", ")}") unless az
    end

    vgw = region.vpn_gateways.create(
      [:vpn_type, :availability_zone].inject({}) do |acc, k|
        resource[k] ? acc.merge!(k => resource[k]) : acc
      end)
    wait_until_state(vgw, :available, 10)

    vgw.attach(find_vpc_item_by_name(resource[:vpc]))
    wait_until_state(nil, :attached, 300) { vgw.attachments.first.state }

    vgw.tags.set({'Name' => resource[:name]}.merge(resource[:tags] || {}))
    vgw
  rescue Exception => e
    fail e
  end

  def destroy
    if @property_hash[:aws_item].vpc
      begin # This blows up if already detached, but I can't find how to work that out. FIXME
        @property_hash[:aws_item].detach(@property_hash[:aws_item].vpc)
        sleep 240 # Double FIXME - We should be able to wait for detached
      rescue
      end
    end
    @property_hash[:aws_item].delete
    @property_hash[:ensure] = :absent
  end
end

