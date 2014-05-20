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
      thingy = mock('object')
      thingy.stubs(:tags).returns({ 'Name' => 'foo' })
      thingy.stubs(:id).returns('vpc-6666')
      thingy.stubs(:cidr_block).returns('10.10.0.0/16')
      thingy.stubs(:dhcp_options_id).returns('FIXME')
      thingy.stubs(:instance_tenancy).returns(:default)
      provider_class.expects(:regions).at_least_once.returns(['us-west-1'])
      provider_class.expects(:vpcs_for_region).returns([thingy])
      provider_class.instances
    end
    if ENV['AWS_ACCESS_KEY']
      it('finds 1 vpc') { expect(instances.size).to eql(1) }
      it('has expected properties') { expect(instances[0].property_hash.reject { |k,v| k == :aws_item }).to \
        eql({:region=>"us-west-1", :cidr=>"10.10.0.0/16", :dhcp_options=>nil, :instance_tenancy=>"default", :ensure=>:present, :name=>"foo", :tags=>{}, :id=>"vpc-6666"}) }
    end
  end
  context "with 2 resources in each of 2 regions in 2 accounts" do
    let(:two_vpcs) {[:vpc1, :vpc2]}
    let(:two_regions) { [:region1, :region2] }
    let(:two_accounts) {[
      {:name => 'a', :access_key_id => 'b', :secret_access_key => 'c' },
      {:name => 'x', :access_key_id => 'y', :secret_access_key => 'z' }
    ]}
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
        ['a', 'x'].include?(a3).should be(true)
        two_accounts.collect {|x| x.reject {|k, v| k==:name}}.include?(a4).should be(true)
        :blah
      end.at_least(:once)
    end

    it "should find 8 instances" do
      provider_class.should_receive(:ec2).at_least(:once).and_return(ec2_mock)
      provider_class.instances(two_accounts).count.should eq(8)
    end
    it "should send a key hash to the ec2 method" do
      expect(provider_class).to receive(:ec2) do |arg|
        arg.each_key do |k|
          [:access_key_id, :secret_access_key].include?(k).should be(true)
        end
        ec2_mock
      end.at_least(:once)
      provider_class.instances(two_accounts).count.should eq(8)
    end
  end
end

