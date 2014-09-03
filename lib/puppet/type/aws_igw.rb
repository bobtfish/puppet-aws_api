require 'puppetx/bobtfish/type_helpers'
Puppet::Type.newtype(:aws_igw) do
  @doc = "Manage AWS internet gateways"
  newparam(:name)
  ensurable
  newproperty(:vpc) do
    include Puppetx::Bobtfish::RequiredValue
  end
  autorequire(:aws_vpc) do
    self[:vpc]
  end
  newproperty(:tags)
  newparam(:route_to_main, :boolean => true)
end

