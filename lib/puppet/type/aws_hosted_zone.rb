Puppet::Type.newtype(:aws_hosted_zone) do
  @doc = "Manage AWS Route 54 hosted zone"
  newparam(:name) do
    desc "Domain name"
  end
  ensurable do
  	self.defaultvalues
    newvalue(:purged) do
      # removes any rrsets contained
      @resource.provider.purge 
    end
  end
end

