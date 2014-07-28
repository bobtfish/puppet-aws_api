require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', '..', 'puppet_x', 'bobtfish', 'ec2_api.rb'))

Puppet::Type.type(:aws_ec2_instance).provide(:api, :parent => Puppet_X::Bobtfish::Ec2_api) do
  mk_resource_methods

  def self.instances_for_region(region)
    ec2.regions[region].instances
  end
  def instances_for_region(region)
    self.class.instances_for_region region
  end
  def self.new_from_aws(region_name, item)
    tags = item.tags.to_h
    name = tags.delete('Name') || item.id
    new(
      :aws_item         => item,
      :name             => name,
      :id               => item.id,
      :ensure           => :present,
      :region           => region_name,
      :image_id         => item.image_id,
      :instance_type    => item.instance_type,
      :iam_role         => item.iam_instance_profile_id,
      :subnet           => item.subnet_id,
      :key_name         => item.key_pair.name,
      :tags             => tags,
      :elastic_ip       => !!item.elastic_ip,
    )
  end
  def self.instances
    regions.collect do |region_name|
      instances_for_region(region_name).collect { |item| new_from_aws(region_name, item) }
    end.flatten
  end
  [:region].each do |ro_method|
    define_method("#{ro_method}=") do |v|
      fail "Cannot manage #{ro_method} is read-only once an instance is created"
    end
  end
  
  def create
    profile = iam.client.get_instance_profile(
      :instance_profile_name => resource[:iam_role]
    )
    subnet = ec2.regions[resource[:region]].subnets.with_tag('Name', resource[:subnet]).first
    instance = ec2.regions[resource[:region]].instances.create(
      :iam_instance_profile => profile[:arn],
      :image_id             => resource[:image_id],
      :instance_type        => resource[:instance_type],
      :subnet               => subnet.id,
      :key_name             => resource[:key_name],
      :associate_public_ip_address => resource[:associate_public_ip_address],
      :block_device_mappings => resource[:block_device_mappings]
    )
    if resource[:elastic_ip]
      elastic_ip = ec2.regions[resource[:region]].elastic_ips.create(
        :vpc => true,
      )
      instance.associate_elastic_ip(elastic_ip)
    end
    wait_until_status instance, :running
    tag_with_name instance, resource[:name]
    tags = resource[:tags] || {}
    tags.each { |k,v| instance.add_tag(k, :value => v) }
    
    instance
  end
  def destroy
    @property_hash[:aws_item].delete
    wait_until_status @property_hash[:aws_item], :terminated
    @property_hash[:ensure] = :absent
  end
end

