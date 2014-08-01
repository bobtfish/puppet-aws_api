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
    def props
    	resource.provider.resource
    end
    def lookup_value
    	if props[:ec2_instance]
    		instance = resource.provider.lookup(:aws_ec2_instance, props[:ec2_instance])
    		# Value matches if ec2_instance public ip matches
    		return instance.elastic_ip.public_ip
    	elsif props[:load_balancer]
    		# Value matches if load_balancer dns_name matches
    		lb = resource.provider.lookup(:aws_elb, props[:load_balancer])
    		return lb.dns_name
    	end
    end
    def should_to_s(newvalue)
    	if newvalue.empty?
    		"#{[lookup_value]} (from #{props[:ec2_instance] or props[:load_balancer]})"
    	else
    		super(newvalue)
    	end
    end
    def insync?(is)
    	if should.empty?
    		# If no value given, use lookup value
    		is == [lookup_value]
    	else
    		# If we have an actual value, just look it up normally
    		super
    	end
    end
  end

  newparam(:ec2_instance) do
  	desc "For CNAME and A records only, an aws_ec2_instance name whose Elastic IP will be used in lieu of the value property."
  end
  autorequire(:aws_ec2_instance) do
    self[:ec2_instance]
  end

  newparam(:load_balancer) do
  	desc "For CNAME records only, an aws_elb name whose external DNS name will be used in lieu of the value property."
  	# TODO: we can definitely add A/AAAA alias target support to this if needed
  end
  autorequire(:aws_elb) do
    self[:load_balancer]
  end

  newproperty(:ttl) do
  	desc "TTL in seconds"
  end
  
end

