# Bundler tasks are defined in rakelib/bundler.rake
#
desc "Run specs"
task "spec" do |t|
  CoreComponents.in_each_dir do
    system "rake spec"
  end
end

desc "Run specs using RCov"
task "spec:rcov" do |t|
  CoreComponents.in_each_dir do
    system "rake spec:rcov"
  end
end

desc "Run integration tests. (Requires a running cloud)"
task "tests" do |t|
  system "cd tests; rake tests"
end

namespace "db" do
  desc "Create or update the configured CloudController database"
  task "migrate" do
    system "cd cloud_controller; rake db:create db:migrate"
  end
end
task "migrate" => "db:migrate"

task :setup do
  # Make submodules sibling of origin
  github_base = %x[git config remote.origin.url].gsub(/\/vcap.git\Z/, '').strip

  %w{java services tests}.each do |git_module|
    if %x[git config submodule.#{git_module}.url].empty?
      url = "#{github_base}/vcap-#{git_module}.git"
      `git config submodule.#{git_module}.url #{url}`
      puts "configure submodule #{git_module}: #{url}"
    end
  end

  sh "git submodule update"
end

task :sync do
  sh "git submodule update"
end
