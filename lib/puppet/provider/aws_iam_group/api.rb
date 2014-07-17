require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', '..', 'puppet_x', 'bobtfish', 'ec2_api.rb'))

Puppet::Type.type(:aws_iam_group).provide(:api, :parent => Puppet_X::Bobtfish::Ec2_api) do
  mk_resource_methods

  def self.new_from_aws(item)
    policies = Hash[item.policies.to_h.map { |k,v| [k,v.to_h] }]
    new(
      :aws_item         => item,
      :name             => item.name,
      :id               => item.id,
      :arn              => item.arn,
      :ensure           => :present,
      :policies         => policies
    )
  end
  def self.instances
    iam.groups.collect { |item| new_from_aws(item) }
  end
  [:arn, :name].each do |ro_method|
    define_method("#{ro_method}=") do |v|
      fail "Cannot manage #{ro_method} is read-only once a user is created"
    end
  end
  def policies=(newpolicies)
    @property_hash[:aws_item].policies.clear
    newpolicies.each do |name,val|
      @property_hash[:aws_item].policies[name] = val
    end
    @property_hash[:policies] = newpolicies
  end
  def create
    begin
      iam.groups.create(resource[:name])
    rescue Exception => e
      fail e
    end
  end
  def destroy
    @property_hash[:aws_item].delete
    @property_hash[:ensure] = :absent
  end
end

