require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', '..', 'puppet_x', 'bobtfish', 'ec2_api.rb'))

Puppet::Type.type(:aws_routetable).provide(:api, :parent => Puppet_X::Bobtfish::Ec2_api) do
  mk_resource_methods
  remove_method :tags= # We want the method inherited from the parent
  read_only :vpc, :subnets, :routes

  def main=(value)
    if value.to_s != 'true'
      debug "Setting :main to false is a noop"
    elsif @property_hash[:aws_item].main?
      @property_hash[:main] = 'true'
    else
      set_as_main!(find_vpc_item_by_name(@property_hash[:vpc]), @property_hash[:aws_item])
    end
  end

  def propagate_from=(value)
    propagate_from!([value].flatten, @property_hash[:aws_item])
  end

  def self.new_from_aws(region_name, item)
    debug "#{self.inspect} #new_from_aws"
    tags = item.tags.to_h
    name = tags.delete('Name') || item.id

    # lol this API
    route_table_attrs = item.send(:describe_call)[:route_table_set][0]
    gw_ids   = route_table_attrs[:propagating_vgw_set].map{|pvs| pvs[:gateway_id]}
    gw_names = ec2.regions[region_name].vpn_gateways.
      inject({}) {|h,vgw| h.merge!(vgw.id => vgw.tags['Name'] || vgw.id) }.
      values_at(*gw_ids)

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
      :propagate_from => gw_names)
  end

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

    route_table = current_region.route_tables.create(:vpc => vpc.id)
    tags = (resource[:tags] || {}).merge('Name' => resource[:name])
    route_table.tags.set(tags)

    set_as_main!(vpc, route_table) if resource[:main].to_s == 'true'
    propagate_from!([resource[:propagate_from]].flatten, route_table) if resource[:propagate_from]

    route_table
  rescue Exception => e
    fail e
  end

  def destroy
    @property_hash[:aws_item].delete
    @property_hash[:ensure] = :absent
  end

  private

  def set_as_main!(vpc, route_table, region=current_region)
    current_main = vpc.route_tables.map do |rt|
      rt.associations.find{ |as| as.main }
    end.compact.first

    if current_main && current_main.route_table.id != route_table.id
      region.client.replace_route_table_association(
        :association_id => current_main.id,
        :route_table_id => route_table.id)
    end

    @property_hash[:main] = 'true'
  end

  def propagate_from!(vgws, route_table, region=current_region)
    gw_coll = region.vpn_gateways.map{|vgw| vgw} # force fetch
    vgws.each do |vgw|
      gateway = gw_coll.find{|gw| gw.tags['Name'] == vgw}
      next unless gateway # should we fail here?

      region.client.enable_vgw_route_propagation(
        :route_table_id => route_table.id,
        :gateway_id     => gateway.id)
    end
  end

  def current_region
    @current_region ||= ec2.regions[find_region_name_for_vpc_name(resource[:vpc])]
  end
end
