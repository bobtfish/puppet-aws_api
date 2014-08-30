require 'puppetx/bobtfish/type_helpers'

Puppet::Type.newtype(:aws_ec2_instance) do
  @doc = "Manage AWS EC2 instances"
  newparam(:name)
  ensurable

  newproperty(:image_id) do
    include Puppetx::Bobtfish::RequiredValue
    newvalues /^ami-[a-f0-9]+$/
  end

  newproperty(:instance_type) do
    include Puppetx::Bobtfish::RequiredValue
    newvalues /^t\d\.\w+$/
  end

  newproperty(:iam_role)

  newproperty(:subnet) do
    include Puppetx::Bobtfish::RequiredValue
  end

  newproperty(:key_name) do
    include Puppetx::Bobtfish::RequiredValue
  end

  newproperty(:tags) do
    include Puppetx::Bobtfish::EnsureHashValue
  end


  newparam(:associate_public_ip_address, :boolean => true)

  newproperty(:elastic_ip, :boolean => true)

  newproperty(:block_device_mappings) do
    defaultto {}
    include Puppetx::Bobtfish::SortedDeepCompare
  end

  newproperty(:security_groups) do
    defaultto do
      sn = resource.provider.lookup(:aws_subnet, resource[:subnet])
      ["#{sn.resource[:vpc]}:default"]
    end
    include Puppetx::Bobtfish::SortedDeepCompare
  end

  autorequire(:aws_subnet) do
    self[:subnet]
  end
  autorequire(:aws_iam_role) do
    self[:iam_role]
  end
  autorequire(:aws_security_group) do
    self[:security_groups]
  end

  newproperty(:public_ip_address) do
    desc "Read-only: public ip of machine"
    include Puppetx::Bobtfish::ReadOnlyProperty
  end

  newparam(:user_data)
end

