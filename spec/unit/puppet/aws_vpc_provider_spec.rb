#!/usr/bin/env rspec
require 'spec_helper'

class Hash
  def to_h
    self
  end
end

provider_class = Puppet::Type.type(:aws_vpc).provider(:api)

class Puppet::Type::Aws_vpc::ProviderApi
  attr_reader :property_hash
end

describe provider_class do
  let(:instances) do
    thingy = mock('object')
    thingy.stubs(:tags).returns({ 'Name' => 'foo' })
    thingy.stubs(:id).returns('vpc-6666')
    thingy.stubs(:cidr_block).returns('10.10.0.0/16')
    thingy.stubs(:dhcp_options_id).returns('FIXME')
    thingy.stubs(:instance_tenancy).returns(:default)
    provider_class.expects(:regions).returns(['us-west-1'])
        provider_class.expects(:regions).returns(['us-west-1'])
    provider_class.expects(:vpcs_for_region).returns([thingy])
    provider_class.instances
  end
  if ENV['AWS_ACCESS_KEY']
    it('finds 1 vpc') { expect(instances.size).to eql(1) }
    it('has expected properties') { expect(instances[0].property_hash.reject { |k,v| k == :aws_item }).to \
      eql({:region=>"us-west-1", :cidr=>"10.10.0.0/16", :dhcp_options_id=>"FIXME", :instance_tenancy=>"default", :ensure=>:present, :name=>"foo", :tags=>{}, :id=>"vpc-6666"}) }
  end
end

