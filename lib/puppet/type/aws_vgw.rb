Puppet::Type.newtype(:aws_vgw) do
  @doc = "Manage AWS virtual private gateways"
  newparam(:name)
  ensurable
  newproperty(:tags)
  newproperty(:vpc)
  autorequire(:aws_vpc) do
   self[:vpc]
  end
  newproperty(:vpn_type) do
  end
  newproperty(:availability_zone) do
  end

  validate do
    if self[:availability_zone]
      if !self[:vpc]
        fail("Cannot set an availability_zone without a vpc")
      end
      my_region = Puppet_X::Bobtfish::Ec2_api.find_region_name_for_vpc_name self[:vpc]
      if !my_region
        fail("Cannot find VPC #{self[:vpc]}")
      end
      if !Puppet_X::Bobtfish::Ec2_api.ec2.regions[my_region].availability_zones.find { |az| az.to_s == self[:availability_zone] }
        fail("Cannot find az '#{self[:availability_zone]}', need to choose.com: #{azs.to_a.join(", ")}")
     end
    end
  end
end

