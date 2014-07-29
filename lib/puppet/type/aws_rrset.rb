Puppet::Type.newtype(:aws_rrset) do
  @doc = "Manage AWS Route 54 resource record sets"
  newparam(:name) do
    desc "Record type followed by name, space sparated (e.g. 'CNAME foo.example.com.')"
  end
  ensurable
  newproperty(:zone) do
  	desc "A aws_hosted_zone name"
  end
  autorequire(:aws_hosted_zone) do
    self[:zone]
  end
  
  newproperty(:value, :array_matching => :all) do
    defaultto []
    desc "The record value string (array of strings for multiple lines)"
  end

  newparam(:ec2_instance) do
  	desc "For CNAME and A records only, an aws_ec2_instance name whose Elastic IP will be used in lieu of the value property."
  end
  autorequire(:aws_ec2_instance) do
    self[:ec2_instance]
  end

  newproperty(:ttl) do
  	desc "TTL in seconds"
  end
  
end

