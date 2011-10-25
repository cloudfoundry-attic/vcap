require 'spec_helper'

describe Resource do

  it "must belong to a valid org" do
    org = Organization.new(:name => "VMware")
    org.should be_valid
    org.save!

    resource = Resource.new(:owner => org, :type => :app)
    resource.should be_valid
    resource.save!
    resource.immutable_id.should_not be_nil
  end

  it "must fail if the org is not valid" do
    pending "Add validation on the resource so that invalid names don't pass'"
    #org = Organization.new(:name => " VMware ")
    #org.should_not be_valid
    #begin
    #  org.save!
    #rescue
    #  #Swallow. Now the row does not exist
    #end
    #
    #resource = Resource.new(:owner => org)
    #expect do
    #  resource.save!
    #end.to raise_error

  end

  it "must delete without any failures" do
    org = Organization.new(:name => "VMware")
    org.should be_valid
    org.save!

    resource = Resource.new(:owner => org, :type => :service)
    resource.should be_valid
    resource.save!

    resource_to_be_deleted = Resource.find_by_id(resource.id)
    Resource.delete(resource_to_be_deleted.id)
    deleted_resource = Resource.find_by_id(resource.id)
    deleted_resource.should be_nil

  end

end
