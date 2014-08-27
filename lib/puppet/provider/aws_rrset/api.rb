require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', '..', 'puppet_x', 'bobtfish', 'aws_api.rb'))

Puppet::Type.type(:aws_rrset).provide(:api, :parent => Puppet_X::Bobtfish::Aws_api) do
  mk_resource_methods

  find_region_from nil

  primary_api :r53

  def self.aws_items_for_region(region)
    r53.hosted_zones.collect { |zone| zone.rrsets.to_a}.flatten
  end

  def self.instance_from_aws_item(region, item)
    name = "#{item.type} #{item.name}"
    new(
      :aws_item         => item,
      :name             => name,
      :ensure           => :present,
      :zone             => item.hosted_zone_id,
      :value            => item.resource_records.collect {|r| r[:value]},
      :ttl              => item.ttl.to_s,
    )
  end

  read_only(:zone)

  def value=(value)
    aws_item.resource_records = get_resource_records
    aws_item.update()
  end

  def ttl=(value)
    aws_item.ttl = value
    aws_item.update()
  end


  def create
    zone = self.class.find_hosted_zone_by_name(resource[:zone])
    zone.rrsets.create(
      record_name,
      record_type,
      :ttl => resource[:ttl].to_i,
      :resource_records => get_resource_records,
    )
  end
  def destroy
    @property_hash[:aws_item].delete
  end

  def record_type
    record_type = split_name[0]
  end

  def record_name
    record_type = split_name[1]
  end

  private

  def split_name
    @split_name ||= begin
      resource[:name].split(' ').tap do |split|
        if split.length != 2
          raise 'AWS resource record set name MUST be in the form of "<type> <name>" - e.g. "CNAME foo.example.com."'
        end
      end
    end
  end

  def get_resource_records
    records = resource[:value].map{|v| {:value => v}}
    if resource[:ec2_instance]
      unless %w(CNAME A).include?(record_type)
        raise "ec2_instance option is for CNAME or A record types only"
      end
      if resource[:value].any? or resource[:load_balancer]
        raise "ec2_instance option can't be used at the same time as value or load_balancer"
      end
      instance = lookup(:aws_ec2_instance, resource[:ec2_instance])
      unless instance.elastic_ip and instance.elastic_ip.public_ip
        raise "ec2_instance reference must have a public Elastic IP"
      end
      records = [{:value => instance.elastic_ip.public_ip}]
    elsif resource[:load_balancer]
      unless %w(CNAME).include?(record_type)
        raise "load_balancer option is for CNAME record types only"
      end
      if resource[:value].any? or resource[:ec2_instance]
        raise "load_balancer option can't be used at the same time as value or ec2_instance"
      end

      records = [{:value => lookup(:aws_elb, resource[:load_balancer]).dns_name}]
    end
    return records
  end

  def wait_until_ready(zone)
    until zone.change_info.status == 'PENDING'
      puts "Zone status is: #{zone.change_info.status}"
      sleep 1
    end
  end

end

