require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'puppet_x', 'bobtfish', 'ec2_api.rb'))

Puppet::Type.newtype(:aws_dopts) do
  @doc = "Manage AWS DHCP Options sets"
  newparam(:name)
  ensurable
  newproperty(:tags)
  newproperty(:region) do
    begin
      Puppet_X::Bobtfish::Ec2_api.regions.each { |name| newvalue name }
    rescue Exception
      []
    end
  end
  newproperty(:domain_name) do
    validate do |value|
      unless value =~ /^[\w\.-]+$/
        raise ArgumentError , "'%s' is not a valid domain_name" % value
      end
    end
  end
  newproperty(:domain_name_servers, :array_matching => :all) do
  end
  newproperty(:ntp_servers, :array_matching => :all) do
  end
  newproperty(:netbios_name_servers, :array_matching => :all) do
  end
  newproperty(:netbios_node_type) do
    defaultto '2'
    validate do |value|
      unless value =~ /^[1248]$/
        raise ArgumentError , "'%s' is not a valid netbios_node_type, can be [1248]" % value
      end
    end
  end
  autorequire(:aws_credentials) do
    requires = []
    res = catalog.resources.find_all do |r|
      r.is_a?(Puppet::Type.type(:aws_credential))
    end
    res.each { |r| requires << r[:name] }
  end
  newparam(:account)
end

