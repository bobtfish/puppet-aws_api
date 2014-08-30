require 'puppetx/bobtfish/type_helpers'

Puppet::Type.newtype(:aws_dopts) do
  @doc = "Manage AWS DHCP Options sets"
  newparam(:name)
  ensurable

  newproperty(:tags) do
    include Puppetx::Bobtfish::EnsureHashValue
  end

  newproperty(:region) do
    include Puppetx::Bobtfish::RequiredValue
    include Puppetx::Bobtfish::RegionValidation
  end

  newproperty(:domain_name) do
    defaultto 'ec2.internal'
    validate do |value|
      unless value =~ /^[\w\.-]+$/
        raise ArgumentError , "'%s' is not a valid domain_name" % value
      end
    end
  end

  newproperty(:domain_name_servers, :array_matching => :all) do
    defaultto ['AmazonProvidedDNS']
  end

  newproperty(:ntp_servers, :array_matching => :all) do
    defaultto []
  end

  newproperty(:netbios_name_servers, :array_matching => :all) do
    defaultto []
  end

  newproperty(:netbios_node_type) do
    defaultto '2'
    validate do |value|
      unless value =~ /^[1248]$/
        raise ArgumentError , "'%s' is not a valid netbios_node_type, can be [1248]" % value
      end
    end
    include Puppetx::Bobtfish::EnsureIntValue
  end
end

