require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', '..', 'puppet_x', 'bobtfish', 'aws_api.rb'))

Puppet::Type.type(:aws_s3_bucket).provide(:api, :parent => Puppet_X::Bobtfish::Aws_api) do
  mk_resource_methods

  def self.instances_for_region(region)
    s3(region).buckets
  end
  def instances_for_region(region)
    self.class.instances_for_region region
  end
  def self.new_from_aws(region_name, item)

    new(
      :aws_item         => item,
      :name             => item.name,
      :ensure           => if item.exists? then :present else :absent end,
      :region           => region_name,
    )
  end

  def self.instances
    regions.collect do |region_name|
      instances_for_region(region_name).collect { |item|
        new_from_aws(region_name, item)
      }
    end.flatten
  end

  read_only(:region)



  def create
    s3_region_string = if resource[:region] == 'us-east-1'
      # yep - this is a special problem with the S3 bucket API alone
      s3(resource[:region]).buckets.create(resource[:name])
    else
      s3(resource[:region]).buckets.create(resource[:name],
        :location_constraint => resource[:region]
      )
    end
  end
  def destroy
    aws_item.delete
    @property_hash[:ensure] = :absent
  end
  def purge
    aws_item.delete!
    @property_hash[:ensure] = :purged
  end

end

