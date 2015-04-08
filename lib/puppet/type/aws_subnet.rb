Puppet::Type.newtype(:aws_subnet) do
  def munge_boolean(value)
    case value
    when true, "true", :true
      :true
    when false, "false", :false
      :false
    else
      fail("munge_boolean only takes booleans")
    end
  end

  @doc = "Manage AWS subnets"
  newparam(:name)
  ensurable
  newproperty(:vpc)
  autorequire(:aws_vpc) { self[:vpc] }
  newproperty(:cidr)
  newproperty(:az)
  newparam(:unique_az_in_vpc) do
    desc "Auto-assign to an AZ not used by any other subnets in this VPC."
  end
  newproperty(:tags)
  newproperty(:route_table)
  newproperty(:auto_assign_ip, :boolean => true) do
    newvalue :true
    newvalue :false

    munge do |value|
      @resource.munge_boolean(value)
    end
  end
end
