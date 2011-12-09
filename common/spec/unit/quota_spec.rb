require 'spec_helper'

describe VCAP::Quota::SetQuota do
  describe '#validate' do
    it 'should require at least one of {:user, :group}' do
      cmd = VCAP::Quota::SetQuota.new
      cmd.filesystem = 'xxx'
      expect do
        cmd.validate
      end.to raise_error(VCAP::Quota::Command::ValidationError, /user/)
    end

    it 'should require :filesystem' do
      cmd = VCAP::Quota::SetQuota.new
      cmd.user = :test
      expect do
        cmd.validate
      end.to raise_error(VCAP::Quota::Command::ValidationError, /filesystem/)
    end

    it 'should require :quotas' do
      cmd = VCAP::Quota::SetQuota.new
      cmd.filesystem = 'xxx'
      cmd.user = :test
      cmd.quotas = nil
      expect do
        cmd.validate
      end.to raise_error(VCAP::Quota::Command::ValidationError, /quotas/)
    end
  end
end

describe VCAP::Quota::RepQuota do
  describe '#validate' do
    it 'should require at least one of {:report_users, :report_groups}' do
      cmd = VCAP::Quota::RepQuota.new
      cmd.report_users = false
      cmd.report_groups = false
      cmd.filesystem = '/'
      expect do
        cmd.validate
      end.to raise_error(VCAP::Quota::Command::ValidationError, /report_users/)
    end

    it 'should require :filesystem' do
      cmd = VCAP::Quota::RepQuota.new
      cmd.report_users = true
      expect do
        cmd.validate
      end.to raise_error(VCAP::Quota::Command::ValidationError, /filesystem/)
    end
  end
end
