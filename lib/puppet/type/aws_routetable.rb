Puppet::Type.newtype(:aws_routetable) do
  @doc = "Manage AWS route tables"
  newparam(:name)
  ensurable
  newproperty(:vpc)
  newproperty(:subnets)
  newproperty(:routes)
  newproperty(:main) do
    newvalue 'true'
    newvalue 'false'
  end
  newproperty(:tags)
  newproperty(:propagate_from, :array_matching => :all)
end

