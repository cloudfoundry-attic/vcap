require 'thread'

require 'vcap/subprocess'

module VCAP
  module ProcessUtils
    STAT_FIELDS = [
      {:name => :rss,   :parse_method => :to_i},
      {:name => :vsize, :parse_method => :to_i},
      {:name => :pcpu,  :parse_method => :to_f},
    ]

    class << self

      def get_stats(pid=nil)
        pid ||= Process.pid

        flags = STAT_FIELDS.map {|f| "-o #{f[:name]}=" }.join(' ')
        begin
          stdout, stderr, status = VCAP::Subprocess.run("ps #{flags} -p #{pid}")
        rescue VCAP::SubprocessStatusError => se
          # Process not running
          if se.status.exitstatus == 1
            return nil
          else
            raise se
          end
        end

        ret = {}
        stdout.split.each_with_index do |val, ii|
          field = STAT_FIELDS[ii]
          ret[field[:name]] = val.send(field[:parse_method])
        end

        ret
      end

    end # class << self
  end   # ProcessUtils
end     # VCAP


