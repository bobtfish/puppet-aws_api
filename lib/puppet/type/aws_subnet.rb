require 'puppetx/bobtfish/type_helpers'

Puppet::Type.newtype(:aws_subnet) do
  @doc = "Manage AWS subnets"

  newparam(:name)

  ensurable

  newproperty(:vpc) do
    include Puppetx::Bobtfish::RequiredValue
  end
  autorequire(:aws_vpc) do
    self[:vpc]
  end

  newproperty(:cidr) do
    include Puppetx::Bobtfish::RequiredValue
    include Puppetx::Bobtfish::CIDRValidation
  end
  newproperty(:az) do
    validate do |value|
      if resource[:unique_az_in_vpc]
        raise ArgumentError, "Can't both specify az and use unique_az_in_vpc option for the same aws_subnet resource."
      end
    end
  end

  newparam(:unique_az_in_vpc, :boolean => true) do
    desc "Auto-assign to an AZ not used by any other subnets in this VPC."
  end

  newproperty(:tags) do
    include Puppetx::Bobtfish::EnsureHashValue
  end

  # TODO: We are setting this, but it doesn't do anything in the backend
  # newproperty(:route_table)
end

