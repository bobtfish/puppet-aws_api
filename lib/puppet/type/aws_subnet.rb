Puppet::Type.newtype(:aws_subnet) do
  @doc = "Manage AWS subnets"
  newparam(:name)
  newparam(:vpc_id)
end

