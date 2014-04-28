#!/usr/bin/env rspec
require 'spec_helper'

type_class = Puppet::Type.type(:aws_test_creds)
provider_class = type_class.provider(:test)

describe provider_class do
  let(:params)  {{:name => "baz", :account => "bar"}}
  let(:instances) { provider_class.instances }
  let(:catalog) { Puppet::Resource::Catalog.new }
  let(:credentials) {[
    {:name => 'bar', :access_key => 'a', :secret_key => 'a'},
    {:name => 'foo', :access_key => 'b', :secret_key => 'b'},
  ]}
  before :each do
    credentials.each do |cred|
      catalog.add_resource(Puppet::Type.type(:aws_credential).new(cred))
    end
    catalog.add_resource type_class.new(params)
  end
  it "should receive an array of credentials as an argument to instances" do
    blah = mock('object')
    blah.expects(:catalog).returns(catalog)
    described_class.expects(:instances) do |arg1|
      cred_names = []
      arg1.each {|x| cred_names << x.name}
      cred_names.sort.should eq(['bar', 'foo'])
      []
    end
    provider_class.prefetch({:foo => blah})
  end
end

def make_a_hash
  Hash.new('hello')
end

describe Hash do
  it "should be mockable using should_receive" do
    described_class.should_receive(:new) do |arg|
      arg.should eq('hello')
      'there'
    end
    make_a_hash.should eq('balls')
  end
end
