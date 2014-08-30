require 'puppetx/bobtfish/aws_api'

Puppet::Type.type(:aws_rrset).provide(:api, :parent => Puppetx::Bobtfish::Aws_api) do

  flushing_resource_methods :read_only => [:zone]

  find_region_from nil

  primary_api :r53

  ensure_from_state(
    true => :present,
    false => :absent,
    &:exists?
  )

  def self.aws_items_for_region(region)
    r53.hosted_zones.collect { |zone| zone.rrsets.to_a}.flatten
  end

  def init_property_hash
    super
    map_init(
      :ttl,
      :zone => :hosted_zone_id
    )
    init :name, "#{record_type} #{record_name}"
    init :value, aws_item.resource_records.collect {|r| r[:value]} # match targets?
  end



  def record_type
    aws_item.type
  end

  def record_name
    aws_item.name
  end

  def flush_when_ready
    flushing :ensure => :absend do
      aws_item.delete
      return
    end

    flushing :ensure => :present do
      zone = lookup(:aws_hosted_zone, resource[:zone])
      zone.rrsets.create(
        record_name,
        record_type,
        :ttl => resource[:ttl].to_i,
        :resource_records => get_resource_records,
      )
    end

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

  private

  def split_name
    @split_name ||= @property_hash[:name].split(' ')
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

