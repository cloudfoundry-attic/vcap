class StagingTask
  attr_reader :app
  attr_reader :task_id
  attr_reader :download_uri
  attr_reader :upload_uri
  attr_reader :upload_path

  class << self
    def create_and_track(app)
      @tasks ||= {}
      task = new(app)
      @tasks[task.task_id] = task
      task
    end

    def find_task(task_id)
      @tasks ||= {}
      @tasks[task_id]
    end

    def untrack(task)
      @tasks ||= {}
      @tasks.delete(task.task_id)
    end

    def untrack_all_tasks
      @tasks = {}
    end
  end

  def initialize(app, opts={})
    @app           = app
    @task_id       = VCAP.secure_uuid
    @download_uri  = staging_uri("/staging/app/#{app.id}")
    @upload_uri    = staging_uri("/staging/droplet/#{app.id}")
    tmpdir         = opts[:tmpdir] || AppConfig[:directories][:tmpdir]
    @upload_path   = File.join(tmpdir, "staged_upload_#{app.id}_#{@task_id}.tgz")
    @nats          = opts[:nats] || NATS.client
  end

  def run(timeout=AppConfig[:staging][:max_staging_runtime])
    stager_client = VCAP::Stager::Ipc::FiberedNatsClient.new(@nats)
    begin
      result = stager_client.add_task(@app.id,
                                      @app.staging_task_properties,
                                      @download_uri,
                                      @upload_uri,
                                      timeout)
    rescue VCAP::Stager::Ipc::RequestTimeoutError
      result = {'error' => 'Timed out waiting for reply from stager'}
    end

    result
  end


  def cleanup
    FileUtils.rm_f(@upload_path)
  end

  private

  def staging_uri(path)
    uri = URI::HTTP.build(
      :host     => CloudController.bind_address,
      :port     => CloudController.external_port,
      :path     => path,
      :query    => "staging_task_id=#{@task_id}"
    )
    uri.to_s
  end

end
