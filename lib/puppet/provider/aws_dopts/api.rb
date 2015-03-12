require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', '..', 'puppet_x', 'bobtfish', 'ec2_api.rb'))

Puppet::Type.type(:aws_dopts).provide(:api, :parent => Puppet_X::Bobtfish::Ec2_api) do
  mk_resource_methods
  remove_method :tags= # We want the method inherited from the parent

  def self.new_from_aws(region_name, item, tags=nil)
    tags ||= item.tags.to_h
    name = tags.delete('Name') || item.id
    c = item.configuration
    new(
      :aws_item         => item,
      :name             => name,
      :id               => item.id,
      :region           => region_name,
      :ensure           => :present,
      :tags                 => tags,
      :domain_name          => c[:domain_name],
      :ntp_servers          => c[:ntp_servers],
      :domain_name_servers  => c[:domain_name_servers],
      :netbios_name_servers => c[:netbios_name_servers],
      :netbios_node_type    => c[:netbios_node_type].to_s
    )
  end

  def self.instances_class; AWS::EC2::DHCPOptions; end

  read_only(:domain_name, :ntp_servers, :netbios_name_servers, :netbios_node_type)

  def create
    begin
      dopts = ec2.regions[resource[:region]].dhcp_options.create({
        :domain_name          => resource[:domain_name],
        :ntp_servers          => resource[:ntp_servers],
        :domain_name_servers  => resource[:domain_name_servers],
        :netbios_name_servers => resource[:netbios_name_servers],
        :netbios_node_type    => resource[:netbios_node_type]
      })
      tag_with_name dopts, resource[:name]
      tags = resource[:tags] || {}
      tags.each { |k,v| dopts.add_tag(k, :value => v) }
      dopts
    rescue Exception => e
      fail e
    end
  end
  def destroy
    @property_hash[:aws_item].delete
    @property_hash[:ensure] = :absent
  end
end

