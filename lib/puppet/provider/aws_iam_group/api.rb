require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', '..', 'puppet_x', 'bobtfish', 'ec2_api.rb'))

Puppet::Type.type(:aws_iam_group).provide(:api, :parent => Puppet_X::Bobtfish::Ec2_api) do
  mk_resource_methods

  def self.new_from_aws(item)
    new(
      :aws_item         => item,
      :name             => item.name,
      :id               => item.id,
      :vpc              => vpc_name,
      :arn              => item.arn,
      :ensure           => :present,
      :tags             => tags
    )
  end
  def self.instances
    iam.groups.collect { |item| new_from_aws(item) }
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

