require 'spec_helper'

describe Organization do

  it "must have a valid name" do
    org = Organization.new :name => "VMware"
    org.save!
    org.immutable_id.should_not be_nil
    org.should be_valid
  end

  it "the name can be an email address" do
    org = Organization.new :name => "jdsa@vmware.com"
    org.should be_valid
  end

  it "must raise an error if the name is invalid" do
    pending "Add validation on the org (resource) so that invalid names don't pass'"
    #org = Organization.new :name => " VMware "
    #org.should have_at_least(1).errors_on(:name)
    #org.should_not be_valid
  end

  it "must raise an error if the name has separate words" do
    pending "Add validation on the org (resource) so that invalid names don't pass'"
    #org = Organization.new :name => " VMware Corporation "
    #org.should have_at_least(1).errors_on(:name)
    #org.should_not be_valid
  end

  it "must raise an error if the name is null" do
    pending "Add validation on the org (resource) so that invalid names don't pass'"
    #org = Organization.new
    #org.should have_at_least(1).errors_on(:name)
    #org.should_not be_valid
  end

  it "must raise an error if the name is really long" do
    org = Organization.new :name => "A" * 5_000_000
    org.should be_valid
  end

  it "must be possible to delete the organization" do
    org = Organization.new :name => "VMware"
    org.should be_valid
    org.save!

    org_to_be_deleted = Organization.find_by_name("VMware")
    org_to_be_deleted.should be_valid
    Organization.delete(org_to_be_deleted.id)

    deleted_org = Organization.find_by_name("VMware")
    deleted_org.should be_nil
  end


end
