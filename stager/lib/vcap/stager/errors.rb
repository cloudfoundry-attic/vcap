module VCAP
  module Stager
    class StagingError          < StandardError; end
    class AppDownloadError      < StagingError;  end
    class DropletUploadError    < StagingError;  end
    class ResultPublishingError < StagingError;  end

    class TaskResultError        < StandardError;   end
    class TaskResultTimeoutError < TaskResultError; end
  end
end
