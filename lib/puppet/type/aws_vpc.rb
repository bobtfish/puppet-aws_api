Puppet::Type.newtype(:aws_vpc) do
  @doc = "Manage AWS vpcs"
  newparam(:name)
end

