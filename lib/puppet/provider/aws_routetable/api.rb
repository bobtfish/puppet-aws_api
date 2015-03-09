require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', '..', 'puppet_x', 'bobtfish', 'ec2_api.rb'))

Puppet::Type.type(:aws_routetable).provide(:api, :parent => Puppet_X::Bobtfish::Ec2_api) do
  mk_resource_methods
  remove_method :tags= # We want the method inherited from the parent

  def self.new_from_aws(region_name, item)
    tags = item.tags.to_h
    name = tags.delete('Name') || item.id
    new(
      :aws_item         => item,
      :name             => name,
      :id               => item.id,
      :ensure           => :present,
      :tags             => tags,
      :main             => item.main? ? 'true' : 'false',
      :vpc              => name_or_id(item.vpc),
      :subnets          => item.subnets.map { |subnet| subnet.tags.to_h['Name'] || subnet.id },
      :routes           => item.routes.map do |route|
        { :destination_cidr_block => route.destination_cidr_block,
          :state => route.state,
          :target => name_or_id(route.target),
          :origin => route.origin,
          :network_interface => name_or_id(route.network_interface),
          :internet_gateway => name_or_id(route.internet_gateway) }.
            reject { |k,v| v.nil? }
      end,
      :propagate_to => [])
  end

  read_only(:vpc, :subnets, :routes, :main, :propagate_to)

  def self.instances
    regions.collect do |region_name|
      ec2.regions[region_name].route_tables.collect { |item| new_from_aws(region_name,item) }
    end.flatten
  end

  def exists?
    @property_hash[:ensure] == :present
  end

  def create
    vpc = find_vpc_item_by_name resource[:vpc]
    fail("Could not find vpc #{resource[:vpc]}") unless vpc

    my_region   = find_region_name_for_vpc_name resource[:vpc]
    region      = ec2.regions[my_region]
    route_table = region.route_tables.create(:vpc => vpc.id)

    tags = (resource[:tags] || {}).merge('Name' => resource[:name])
    region.client.create_tags(
      :resources => [route_table.id],
      :tags => tags.map {|k,v| {:key => k, :value => v}})

    if resource[:main].to_s == 'true' # fuck puppet
      current_main = vpc.route_tables.map do |rt|
        rt.associations.find{ |as| as.main }
      end.compact.first

      if current_main && current_main.route_table.id != route_table.id
        region.client.replace_route_table_association(
          :association_id => current_main.id,
          :route_table_id => route_table.id)
      end
    end

    if resource[:propagate_to]
      gw_coll = region.vpn_gateways.map{|vgw| vgw} # force fetch
      [resource[:propagate_to]].flatten.each do |gw_resource|
        gateway = gw_coll.find{|gw| gw.tags['Name'] == gw_resource.title}
        next unless gateway

        region.client.enable_vgw_route_propagation(
          :route_table_id => route_table.id,
          :gateway_id     => gateway.id)
      end
    end

    route_table
  rescue Exception => e
    fail e
  end

  def destroy
    @property_hash[:aws_item].delete
    @property_hash[:ensure] = :absent
  end
end
