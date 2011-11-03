class JobManager
  [NATS, CF, CCDB].each do |job|
    task job.to_sym do
      install(job)
    end
  end

  [CC, HM].each do |job|
    task job.to_sym => [CF.to_sym, NATS.to_sym, CCDB.to_sym] do
      install(job)
    end
  end

  [ROUTER, ROUTERV2, DEA].each do |job|
    task job.to_sym => [CF.to_sym, NATS.to_sym] do
      install(job)
    end
  end

  SERVICES_NODE.each do |job|
    task job.to_sym => [CF.to_sym, NATS.to_sym] do
      install(job)
    end
  end

  SERVICES_GATEWAY.each do |job|
    task job.to_sym => [CF.to_sym, CC.to_sym, NATS.to_sym] do
      install(job)
    end
  end

  all_jobs = []
  JOBS.each do |job|
    if job.to_s == ROUTERV2.to_s then next end # Skip routerv2 if installing "all"

    all_jobs << job.to_sym if job != ALL
  end

  task ALL.to_sym => all_jobs
  task :default => ALL.to_sym
end
