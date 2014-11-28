require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', '..', 'puppet_x', 'bobtfish', 'ec2_api.rb'))


Puppet::Type.type(:aws_hosted_zone).provide(:api, :parent => Puppet_X::Bobtfish::Ec2_api) do
  mk_resource_methods
  remove_method :tags= # We want the method inherited from the parent

  def self.new_from_aws(item)
    new(
      :aws_item         => item,
      :name             => item.name,
      :ensure           => :present,
    )
  end
  def self.instances
    r53.hosted_zones.collect { |item| new_from_aws(item) }
  end


  def create
    unless resource[:name].end_with? '.'
      raise "Hosted zone name must terminate with a dot - e.g. 'example.com.', not 'example.com' "
    end
    r53.hosted_zones.create(resource[:name])
  end
  def destroy
    aws_item.delete
    @property_hash[:ensure] = :absent
  end

  def purge
    aws_item.rrsets.each do |rrset|
      # can't delete NS/SOA to self
      unless %w(NS SOA).include?(rrset.type)  and rrset.name == aws_item.name
        rrset.delete
      end
    end
    aws_item.delete
    @property_hash[:ensure] = :purged
  end

end

