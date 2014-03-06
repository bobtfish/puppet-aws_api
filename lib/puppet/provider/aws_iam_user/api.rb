require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', '..', 'puppet_x', 'bobtfish', 'ec2_api.rb'))
require 'set'

Puppet::Type.type(:aws_iam_user).provide(:api, :parent => Puppet_X::Bobtfish::Ec2_api) do
  mk_resource_methods

  def self.new_from_aws(item)
    new(
      :aws_item         => item,
      :name             => item.name,
      :id               => item.id,
      :arn              => item.arn,
      :path             => item.path,
      :groups           => item.groups.map { |g| g.name },
      :ensure           => :present
    )
  end
  def self.instances
    iam.users.collect { |item| new_from_aws(item) }
  end
  [:arn, :path, :name].each do |ro_method|
    define_method("#{ro_method}=") do |v|
      fail "Cannot manage #{ro_method} is read-only once a user is created"
    end
  end
  def groups=(newgroups)
    groups_to_add = Set.new(newgroups).subtract(@property_hash[:groups]).to_a.map { |name| iam.groups[name] }
    groups_to_remove = Set.new(@property_hash[:groups]).subtract(newgroups).to_a.map { |name| iam.groups[name] }
    puts groups_to_add.inspect
    puts groups_to_remove.inspect
  end
  def create
    begin
      iam.users.create(resource[:name], :path => resource[:path])
    rescue Exception => e
      fail e
    end
  end
  def destroy
    @property_hash[:aws_item].delete
    @property_hash[:ensure] = :absent
  end
end

