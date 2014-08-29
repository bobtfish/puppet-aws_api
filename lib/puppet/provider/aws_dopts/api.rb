require 'puppetx/bobtfish/aws_api'

Puppet::Type.type(:aws_dopts).provide(:api, :parent => Puppetx::Bobtfish::Aws_api) do
  include Puppetx::Bobtfish::TaggableProvider

  flushing_resource_methods :read_only => [
    :region, :domain_name, :ntp_servers, :netbios_name_servers, :netbios_node_type
  ]

  find_region_from :region

  primary_api :ec2, :collection => :dhcp_options

  ensure_from_state :exists?

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

  def preventable_flush
    puts "FLUSH YOUR FACE"
    puts resource[:domain_name_servers].inspect
    puts resource[:ntp_servers].inspect
    creating? do
      config = {
        :domain_name          => resource[:domain_name],
        :domain_name_servers  => resource[:domain_name_servers],
      }
      [:ntp_servers, :netbios_name_servers, :netbios_node_type].each do |opt|
        config[opt] = resource[opt] unless resource[opt].nil? or resource[opt].empty?
      end
      collection.create(config)
    end
    super
  end
end

