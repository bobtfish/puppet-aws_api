#!/usr/bin/env rspec
#require 'spec_helper'
require 'puppet'

type_class = Puppet::Type.type(:aws_test_creds)
provider_class = type_class.provider(:test)


describe provider_class do
  let(:params)  {{:name => "baz", :account => "bar"}}
  let(:instances) { provider_class.instances }
  let(:catalog) { Puppet::Resource::Catalog.new }

  it('does not have any instances') do
    expect(instances.size).to eql 0
  end

  it "#extract_creds should be able to return a hash of the credentials" do
    credential_hash ={:name => 'bar', :access_key => 'a', :secret_key => 'b' }
    credential = Puppet::Type.type(:aws_credential).new(credential_hash)

    described_class.extract_creds(credential).should eq(
      { :name => 'bar', :access_key_id => 'a', :secret_access_key => 'b' }
    )
  end


  context "with credentials in the catalog" do
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
      blah = double('object')
      expect(blah).to receive(:catalog).and_return(catalog)
      described_class.should_receive(:instances) do |arg1|
        cred_names = []
        arg1.each {|x| cred_names << x[:name]}
        cred_names.sort.should eq(['bar', 'foo'])
        []
      end
      provider_class.prefetch({:foo => blah})
    end
  end
end

describe type_class do
  params = {:name => "baz", :account => "bar"}
  credential_hash = {:name => "bar", :access_key => "baz", :secret_key => "foo"}
  let(:credentials) { Puppet::Type.type(:aws_credential).new({
    :name => "baz",
    :access_key => "foo",
    :secret_key => "bar"
  })}
  let(:provider) { provider_class.new }
  let(:catalog) { Puppet::Resource::Catalog.new }
  let(:resource) {
    resource = double('object')
    expect(resource).to receive(:catalog).and_return(catalog).at_least(:once)
    expect(resource).to receive(:[]).and_return('baz').at_least(:once)
    resource
  }
  it "should be able to create an instance" do
    described_class.new(params).should_not be_nil
  end

  context "with credentials added" do
    before :each do
      catalog.add_resource credentials
      catalog.add_resource described_class.new(params)
      expect(provider).to receive(:resource).and_return(resource).at_least(:once)
    end

    it "should make credentials queryable from the catalog" do
      lambda { provider.create }.should_not raise_error
    end
    it "should not access the default credentials" do
      lambda { provider.create }.should_not raise_error
      provider.get_creds.should eq({
        :access_key_id => "foo", :secret_access_key => "bar"})
    end
    it "should return the same credentials twice" do
      lambda { provider.create }.should_not raise_error
      provider.get_creds.should eq({
        :access_key_id => "foo", :secret_access_key => "bar"})
      provider.get_creds.should eq({
        :access_key_id => "foo", :secret_access_key => "bar"})
    end
  end
  context "with wrong redentials referenced" do
    it "should use the default credentials" do
      catalog.add_resource credentials
      catalog.add_resource described_class.new(:name => "foo", :account => "bernard")
      lambda { provider.create }.should_not raise_error
      provider.get_creds.should eq( {
        :access_key_id => (ENV['AWS_ACCESS_KEY_ID']||ENV['AWS_ACCESS_KEY']), 
        :secret_access_key => (ENV['AWS_SECRET_ACCESS_KEY']||ENV['AWS_SECRET_KEY'])
      })
    end
  end
  context "without credentials added" do
    it "should use the default credentials" do
      catalog.add_resource described_class.new(params)
      lambda { provider.create }.should_not raise_error
      provider.get_creds.should eq( {
        :access_key_id => (ENV['AWS_ACCESS_KEY_ID']||ENV['AWS_ACCESS_KEY']), 
        :secret_access_key => (ENV['AWS_SECRET_ACCESS_KEY']||ENV['AWS_SECRET_KEY'])
      })
    end
  end
  context "with instances in the catalog" do
    let(:credentials) {[
      {:name => 'bar', :access_key => 'a', :secret_key => 'a'},
      {:name => 'foo', :access_key => 'b', :secret_key => 'b'},
    ]}
    let(:instance) {described_class.new(params)}
    before :each do 
      credentials.each do |cred| 
        catalog.add_resource(Puppet::Type.type(:aws_credential).new(cred))
      end
      catalog.add_resource instance
    end

    it "should be able to extract resources from the catalog by account" do
      res = catalog.resources.find_all do |r|
        r.is_a?(described_class) && r[:account] == 'bar'
      end
      res.count.should eq(1)
      res[0].name.should eq('baz')
    end
    it "should be able to create" do
      instance.provider.create
    end
    it "should be able to use instance method get_creds and creds are cached" do
      instance.provider.get_creds.should eq({:access_key_id => 'a',
                                             :secret_access_key => 'a'})
      # This tests that they are cached as they should be
      instance.provider.creds.should eq({:access_key_id => 'a',
                                          :secret_access_key => 'a'})
      instance.provider.get_creds.should eq({:access_key_id => 'a',
                                    :secret_access_key => 'a'})
    end
  end
end

