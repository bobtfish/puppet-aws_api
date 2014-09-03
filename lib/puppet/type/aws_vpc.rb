require 'puppetx/bobtfish/type_helpers'
Puppet::Type.newtype(:aws_vpc) do
  @doc = "Manage AWS vpcs"
  newparam(:name)
  ensurable do
    include Puppetx::Bobtfish::Purgable
  end

  newproperty(:region) do
    include Puppetx::Bobtfish::RequiredValue
    include Puppetx::Bobtfish::RegionValidation
  end

  newproperty(:cidr) do
    include Puppetx::Bobtfish::RequiredValue
    include Puppetx::Bobtfish::CIDRValidation
  end

  newproperty(:dhcp_options)
  autorequire(:aws_dopts) do
    self[:dhcp_options]
  end

  newproperty(:instance_tenancy) do
    newvalues :default, :dedicated
    defaultto :default
  end

  newproperty(:tags) do
    include Puppetx::Bobtfish::EnsureHashValue
  end
end

