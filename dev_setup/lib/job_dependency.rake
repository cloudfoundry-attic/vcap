class JobManager
  [NATS, CCDB, CF].each do |job|
    task job.to_sym do
      install(job)
    end
  end

  [CC, HM].each do |job|
    task job.to_sym => [CF.to_sym, NATS.to_sym, CCDB.to_sym] do
      install(job)
    end
  end

  [ROUTER, DEA].each do |job|
    task job.to_sym => [CF.to_sym, NATS.to_sym] do
      install(job)
    end
  end

  [MYSQL, REDIS, MONGODB, POSTGRESQL].each do |job|
    task job.to_sym => [CF.to_sym, CC.to_sym] do
      install(job)
    end
  end

  all_jobs = Array.new
  JOBS.each do |job|
    all_jobs << job.to_sym
  end

  task ALL.to_sym => all_jobs
  task :default => ALL.to_sym
end
