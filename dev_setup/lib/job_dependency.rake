class JobManager
  [NATS, CF, CCDB, ACMDB, UAADB, VCAP_REDIS].each do |job|
    task job.to_sym do
      install(job)
    end
  end

  [CC, HM].each do |job|
    task job.to_sym => [CF.to_sym, NATS.to_sym, CCDB.to_sym] do
      install(job)
    end
  end

  [ROUTER, DEA, UAA, ACM].each do |job|
    task job.to_sym => [CF.to_sym, NATS.to_sym] do
      install(job)
    end
  end

  SERVICE_TOOLS.each do |job|
    task job.to_sym => [CF.to_sym, NATS.to_sym] do
      install(job)
    end
  end

  SERVICE_LIFECYCLE.each do |job|
    task job.to_sym => [CF.to_sym, NATS.to_sym, VCAP_REDIS.to_sym] do
      install(job)
    end
  end

  SERVICES_NODE.each do |job|
    task job.to_sym => [CF.to_sym, NATS.to_sym, VCAP_REDIS.to_sym] do
      install(job)
    end
  end

  SERVICES_WORKER.each do |job|
    task job.to_sym => [VCAP_REDIS.to_sym] do
      install(job)
    end
  end

  SERVICES_GATEWAY.each do |job|
    task job.to_sym => [CF.to_sym, CC.to_sym, NATS.to_sym] do
      install(job)
    end
  end

  SERVICES_AUXILIARY.each do |job|
    task job.to_sym => [CF.to_sym, CC.to_sym, NATS.to_sym] do
      install(job)
    end
  end

  all_jobs = []
  JOBS.each do |job|
    all_jobs << job.to_sym if job != ALL
  end

  task ALL.to_sym => all_jobs
  task :default => ALL.to_sym
end
