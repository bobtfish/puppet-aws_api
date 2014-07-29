Puppet::Type.newtype(:aws_hosted_zone) do
  @doc = "Manage AWS Route 54 hosted zone"
  newparam(:name) do
    desc "Domain name"
  end
  ensurable
end

