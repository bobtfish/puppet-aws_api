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
  context "with vpc object mocked" do
    let(:instances) do
      thingy = double()
      allow(thingy).to receive(:tags).and_return({ 'Name' => 'foo' })
      allow(thingy).to receive(:id).and_return('vpc-6666')
      allow(thingy).to receive(:cidr_block).and_return('10.10.0.0/16')
      allow(thingy).to receive(:dhcp_options_id).and_return('FIXME')
      allow(thingy).to receive(:instance_tenancy).and_return(:default)
      expect(provider_class).to receive(:regions).and_return(['us-west-1'])
      expect(provider_class).to receive(:vpcs_for_region).and_return([thingy])
      provider_class.instances
    end
    if ENV['AWS_ACCESS_KEY']
      it('finds 1 vpc') { expect(instances.size).to eql(1) }
      it('has expected properties') { expect(instances[0].property_hash.reject { |k,v| k == :aws_item }).to \
        eql({:region=>"us-west-1", :cidr=>"10.10.0.0/16", :dhcp_options=>nil, :instance_tenancy=>"default", :ensure=>:present, :name=>"foo", :tags=>{}, :id=>"vpc-6666"}) }
    end
  end
  context "with 2 resources in each of 2 regions" do
    let(:two_vpcs) {[:vpc1, :vpc2]}
    let(:two_regions) { [:region1, :region2] }
    let(:ec2_mock) {
      ec2_mock = double 'object'
      ec2_mock.stub_chain('regions.[].vpcs').and_return(two_vpcs)
      ec2_mock
    }

    before :each do
      provider_class.should_receive(:regions).and_return(two_regions)
      expect(provider_class).to receive(:new_from_aws) do |a1, a2, a3, a4|
        [:region1, :region2].include?(a1).should be(true)
        [:vpc1, :vpc2].include?(a2).should be(true)
        :blah
      end.at_least(:once)
    end

    it "should find 4 instances" do
      provider_class.should_receive(:ec2).at_least(:once).and_return(ec2_mock)
      provider_class.instances.count.should eq(4)
    end
    it "should send a key hash to the ec2 method" do
      expect(provider_class).to receive(:ec2) do
        ec2_mock
      end.at_least(:once)
      provider_class.instances.count.should eq(4)
    end
  end
end

