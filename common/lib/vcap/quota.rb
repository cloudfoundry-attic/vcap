module VCAP
  module Quota

    class Command
      class ValidationError < StandardError; end

      def run
        validate
        command = build_command
        result = execute(command)
        parse_result(result)
      end

      def validate
        nil
      end

      def build_command
        raise NotImplementedError
      end

      def execute(command)
        stdout = `#{command}`
        [$?, stdout]
      end

      def parse_result(result)
        result
      end

      private

      def assert_at_least_one_of(*fields)
        for field in fields
          has_value = send(field.to_sym)
          return if has_value
        end
        raise ValidationError, "At least one of {#{fields.join(', ')}} must be set"
      end

      def assert_at_most_one_of(*fields)
        existing_fields = fields.inject([]) do |accum, field|
          accum << field unless send(field.to_sym)
          accum
        end
        unless existing_fields.length == 1
          raise ValidationError, "At most one of #{fields.join(', ')} must be set"
        end
      end
    end

    class SetQuota < Command
      attr_accessor :user
      attr_accessor :group
      attr_accessor :filesystem
      attr_accessor :quotas

      def initialize
        @quotas = {
          :block => {
            :soft => 0,
            :hard => 0,
          },
          :inode => {
            :soft => 0,
            :hard => 0,
          },
        }
      end

      def validate
        assert_at_least_one_of(:user)
        assert_at_least_one_of(:filesystem)
        assert_at_least_one_of(:quotas)
      end

      private

      def build_command
        cmd = ['setquota']
        cmd << ['-u', self.user] if self.user
        cmd << ['-g', self.group] if self.group
        cmd << [self.quotas[:block][:soft], self.quotas[:block][:hard],
                self.quotas[:inode][:soft], self.quotas[:inode][:hard]]
        cmd << self.filesystem
        cmd.flatten.join(' ')
      end
    end

    class RepQuota < Command
      attr_accessor :report_groups
      attr_accessor :report_users
      attr_accessor :ids_only
      attr_accessor :filesystem

      def initialize
        @report_users = true
      end

      def validate
        assert_at_least_one_of(:report_groups, :report_users)
        assert_at_least_one_of(:filesystem)
      end

      def build_command
        cmd = ['repquota', '-p'] # -p reports grace as 0 when unset
        cmd << '-u' if self.report_users
        cmd << '-g' if self.report_groups
        cmd << '-n' if self.ids_only
        cmd << self.filesystem
        cmd = cmd.flatten.join(' ')
        cmd
      end

      def parse_result(result)
        if result[0] == 0
          quota_info = {}
          result[1].lines.each do |line|
            next unless line.match(/[^\s]+\s+[+-]+\s+\d+/)
            fields = line.split(/\s+/)
            if self.ids_only
              match = fields[0].match(/^#(\d+)$/)
              uid = match[1].to_i
            else
              uid = fields[0]
            end
            quota_info[uid] = {
              :usage => {
                :block => fields[2].to_i,
                :inode => fields[6].to_i
              },
              :quotas => {
                :block => {
                  :soft => fields[3].to_i,
                  :hard => fields[4].to_i,
                },
                :inode => {
                  :soft => fields[7].to_i,
                  :hard => fields[8].to_i,
                },
              }
            }
          end
          [true, quota_info]
        else
          [false, result]
        end
      end
    end

  end # VCAP::Quota
end
