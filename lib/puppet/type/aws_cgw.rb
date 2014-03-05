require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'puppet_x', 'bobtfish', 'ec2_api.rb'))

Puppet::Type.newtype(:aws_cgw) do
  @doc = "Manage AWS customer gateways: http://docs.aws.amazon.com/AWSEC2/latest/CommandLineReference/ApiReference-cmd-CreateCustomerGateway.html"
  newparam(:name)
  ensurable
  newproperty(:ip_address) do
    validate do |value|
      unless value =~ /^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$/
        raise ArgumentError , "'%s' is not a valid IPv4 address" % value
      end
    end
  end
  newproperty(:bgp_asn) do
    validate do |value|
      unless value =~ /^\d+$/
        raise ArgumentError , "'%s' is not a valid BGP ASN" % value
      end
    end
  end
  newproperty(:tags) do
  end
  newproperty(:region) do
    Puppet_X::Bobtfish::Ec2_api.regions.each { |name| newvalue name }
  end
  newproperty(:type) do
    defaultto 'ipsec.1'
    validate do |value|
      unless value =~ /^ipsec\.1$/
        raise ArgumentError , "'%s' is not a valid type" % value
      end
    end
  end
end

