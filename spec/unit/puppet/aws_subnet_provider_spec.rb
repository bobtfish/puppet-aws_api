#!/usr/bin/env rspec
require 'spec_helper'

provider_class = Puppet::Type.type(:aws_subnet).provider(:api)

describe provider_class do
  context "with 2 resources in each of 2 vpcs in each of 2 regions" do
    let(:two_vpcs) {
      [:vpc1, :vpc2].collect do |v|
        vpc = double 'object'
        vpc.stub('name').and_return v
        vpc.stub('subnets').and_return [:subnet1, :subnet2]
        vpc
      end
    }
    let(:two_regions) { [:region1, :region2] }
    let(:ec2_mock) {
      ec2_mock = double 'object'
      ec2_mock.stub_chain('regions.[].vpcs').and_return(two_vpcs)
      ec2_mock
    }

    before :each do
      provider_class.should_receive(:regions).and_return(two_regions)
      expect(provider_class).to receive(:new_from_aws) do |a1, a2|
        [:vpc1, :vpc2].include?(a1).should be(true)
        [:subnet1, :subnet2].include?(a2).should be(true)
        :blah
      end.at_least(:once)
      expect(provider_class).to receive(:name_or_id) {|arg| arg.name}.at_least(:once)
    end

    it "should find 8 instances" do
      expect(provider_class).to receive(:ec2).and_return(ec2_mock).at_least(:once)
      provider_class.instances.count.should eq(8)
    end
    it "should send a key hash to the ec2 method" do
      expect(provider_class).to receive(:ec2) do
        ec2_mock
      end.at_least(:once)
      provider_class.instances.count.should eq(8)
    end
  end
end

