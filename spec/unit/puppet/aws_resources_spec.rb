#!/usr/bin/env rspec
require 'spec_helper'

type_class = Puppet::Type.type(:aws_resources)

describe type_class do
  context "with no parameters" do
    before (:each) do 
      @res = type_class.new :name => 'aws_cgw' 
      @res.catalog = Puppet::Resource::Catalog.new
      @res
    end

    describe "#generate" do
      it "should throw an exception" do
        lambda { @res.generate }.should raise_error
      end
    end
  end
  context "with an account parameter" do
    before :each do
      creds = {:name => 'bleh', :access_key => 'a', :secret_key => 'b'}
      @catalog = Puppet::Resource::Catalog.new
      cred = Puppet::Type.type(:aws_credential).new(creds)
      @catalog.add_resource cred
    end

    describe "#new" do
      it "should not throw any exceptions" do
        expect{
          res = type_class.new({:name => 'aws_cgw', :account => 'bleh'})
          res.catalog = @catalog
        }.to_not raise_error
      end
    end

    describe "#generate" do
      before :each do
        @res = type_class.new({:name => 'aws_cgw', :account => 'bleh'})
        @res.catalog = @catalog
      end
      it "should not throw any exceptions" do
        expect {@res.generate}.to_not raise_error
      end
    end
  end
  context "with an account parameter and purge set to true" do
    before :each do
      @creds = {:name => 'bleh', :access_key => 'a', :secret_key => 'b'}
      @catalog = Puppet::Resource::Catalog.new
      cred = Puppet::Type.type(:aws_credential).new(@creds)
      @catalog.add_resource cred
      @res = type_class.new({:name => 'aws_cgw', :account => 'bleh', :purge => true})
      @catalog.add_resource @res
      @managed_resource = Puppet::Type.type(:aws_cgw)
    end
    it "should pass credentials to instances" do
      expect(@managed_resource).to receive(:instances) do |arg|
        arg.should eq([{:name => 'bleh', :access_key_id => 'a', :secret_access_key => 'b'}])
        []
      end
      @res.generate.should eq []
    end
  end
end
