require 'puppetx/bobtfish/aws_api'

Puppet::Type.type(:aws_dopts).provide(:api, :parent => Puppetx::Bobtfish::Aws_api) do
  include Puppetx::Bobtfish::TaggableProvider

  flushing_resource_methods :read_only => [
    :region, :domain_name, :ntp_servers, :netbios_name_servers, :netbios_node_type
  ]

  find_region_from :region

  primary_api :ec2, :collection => :dhcp_options

  ensure_from_state(
    true => :present,
    false => :absent,
    &:exists?
  )

  def init_property_hash
    super
    [
      :domain_name,
      :ntp_servers,
      :domain_name_servers,
      :netbios_name_servers,
      :netbios_node_type
    ].each do |opt|
      init opt, aws_item.configuration[opt]
    end
  end

  def flush_when_ready
    flushing :ensure => :absent do
      aws_item.delete
      return
    end
    flushing :ensure => :present do
      config = {
        :domain_name          => resource[:domain_name],
        :domain_name_servers  => resource[:domain_name_servers],
      }
      [:ntp_servers, :netbios_name_servers, :netbios_node_type].each do |opt|
        cfg_value = resource[opt]
        config[opt] = cfg_value unless cfg_value.nil? or (cfg_value.is_a?(Array) and cfg_value.empty?)
      end
      collection.create(config)
    end
    super
  end
end

