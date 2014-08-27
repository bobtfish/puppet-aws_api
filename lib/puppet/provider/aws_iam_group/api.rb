require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', '..', 'puppet_x', 'bobtfish', 'aws_api.rb'))

Puppet::Type.type(:aws_iam_group).provide(:api, :parent => Puppet_X::Bobtfish::Aws_api) do
  mk_resource_methods

  find_region_from nil

  primary_api :iam, :collection => :groups

  def self.instance_from_aws_item(region, item)
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

  read_only(:arn, :name, :policies) # can name even change?, can arn actually be set?

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

