#!/usr/bin/env rspec
require 'spec_helper'

type_class = Puppet::Type.type(:aws_credential)
provider_class = type_class.provider(:api)

describe provider_class do
  let(:instances) { provider_class.instances }

  it('does not have any instances') do
    expect(instances.size).to eql 0
  end
end

describe type_class do
  params = {:name => "baz", :access_key => "foo", :secret_key => "bar"}
  it "should be able to create an instance" do
    described_class.new(params).should_not be_nil
  end

  params.each_key do |param|
    it "should accept #{param} parameter" do
      described_class.attrtype(param).should == :param
    end

    it "should fail if #{param} is not given" do
      other_params = params.reject {|k, _| k == param}
      expect { described_class.new(other_params)}.to raise_error
    end
  end

  it "should make account queryable from the catalog" do
    new_creds = described_class.new(params)
    catalog = Puppet::Resource::Catalog.new
    catalog.add_resource new_creds
    creds = []
    catalog.resources.find_all {|r| creds.push r if r.is_a?(type_class)}
    creds[0].title.should eq("baz")
  end
end

