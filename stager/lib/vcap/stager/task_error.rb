require 'yajl'

require 'vcap/json_schema'

module VCAP
  module Stager

    # A TaskError is a recoverable error that indicates any further task
    # processing should be aborted and the task should be completed in a failed
    # state. All other errors thrown during VCAP::Stager::Task#perform will be
    # logged and re-raised (probably causing the program to crash).
    class TaskError < StandardError
      SCHEMA = VCAP::JsonSchema.build do
        { :class => String,
          optional(:details) => String,
        }
      end

      class << self
        attr_reader :desc

        def desc
          @desc || "Staging task failed"
        end

        def set_desc(desc)
          @desc = desc
        end

        def decode(enc_err)
          dec_err   = Yajl::Parser.parse(enc_err)
          SCHEMA.validate(dec_err)
          err_class = dec_err['class'].split('::').last
          VCAP::Stager.const_get(err_class.to_sym).new(dec_err['details'])
        end
      end

      attr_reader :details

      def initialize(details=nil)
        @details = details
      end

      def to_s
        @details ? "#{self.class.desc}:\n #{@details}" : self.class.desc
      end

      def encode
        h = {:class => self.class.to_s}
        h[:details] = @details if @details
        Yajl::Encoder.encode(h)
      end
    end

    class AppDownloadError     < TaskError; set_desc "Failed downloading application from the Cloud Controller";  end
    class AppUnzipError        < TaskError; set_desc "Failed unzipping application";                              end
    class StagingPluginError   < TaskError; set_desc "Staging plugin failed staging application";                 end
    class StagingTimeoutError  < TaskError; set_desc "Staging operation timed out";                               end
    class DropletCreationError < TaskError; set_desc "Failed creating droplet";                                   end
    class DropletUploadError   < TaskError; set_desc "Failed uploading droplet to the Cloud Controller";          end
    class InternalError        < TaskError; set_desc "Unexpected internal error encountered (possibly a bug).";   end
  end
end
