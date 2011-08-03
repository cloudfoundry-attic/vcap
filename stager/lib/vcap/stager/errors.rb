module VCAP
  module Stager
    class StagingError          < StandardError; end
    class AppDownloadError      < StagingError;  end
    class DropletUploadError    < StagingError;  end
    class ResultPublishingError < StagingError;  end
  end
end
