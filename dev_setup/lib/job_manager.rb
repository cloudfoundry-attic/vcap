#!/usr/bin/env ruby
require 'rake'
require 'yaml'
require 'set'
require 'pp'

$LOAD_PATH.unshift(File.dirname(__FILE__))

class JobManager
  ALL = "all"
  NATS = "nats_server"
  ROUTER = "router"
  CC = "cloud_controller"
  CCDB = "ccdb"
  CF = "cloudfoundry"
  HM = "health_manager"
  DEA = "dea"
  UAA = "uaa"
  UAADB = "uaadb"
  ACM = "acm"
  ACMDB = "acmdb"

  SERVICES = ["redis", "mysql", "mongodb", "neo4j"]
  SERVICES_NODE = SERVICES.map do |service|
    "#{service}_node"
  end
  SERVICES_GATEWAY = SERVICES.map do |service|
    "#{service}_gateway"
  end
  SERVICES_NODE.each do |node|
    # Service name constant e.g. REDIS_NODE -> "redis_node"
    const_set(node.upcase, node)
  end

  # All supported jobs
  JOBS = [ALL, NATS, ROUTER, CF, CC, HM, DEA, CCDB, UAA, UAADB, ACM, ACMDB] + SERVICES_NODE + SERVICES_GATEWAY
  SYSTEM_JOB = [CF]

  # List of the required properties for jobs
  INSTALLED_JOB_PROPERTIES = {NATS => ["host"], CC => ["service_api_uri", "builtin_services"],
                              CCDB => ["host"]}
  INSTALL_JOB_PROPERTIES = {CC => ["builtin_services"], MYSQL_NODE => ["index"], MONGODB_NODE => ["index"], REDIS_NODE => ["index"], NEO4J_NODE => ["index"]}

  # Dependency between JOBS and  components that are consumed by "vcap_dev" when cf is started or
  # stopped
  SERVICE_NODE_RUN_COMPONENTS = Hash.new
  SERVICES_NODE.each do |node|
    SERVICE_NODE_RUN_COMPONENTS[node] = node
  end

  SERVICE_GATEWAY_RUN_COMPONENTS = Hash.new
  SERVICES_GATEWAY.each do |gateway|
    SERVICE_GATEWAY_RUN_COMPONENTS[gateway] = gateway
  end

  RUN_COMPONENTS = {ROUTER => ROUTER, CC => CC, HM => HM, DEA => DEA, UAA => UAA, ACM => ACM}.update(SERVICE_NODE_RUN_COMPONENTS).update(SERVICE_GATEWAY_RUN_COMPONENTS)

  class << self
    if defined?(Rake::DSL)
      include Rake::DSL
    end
    # Take user input and create a Hash that has the job name as the key and its
    # properties as value.
    #
    # Allows the user to specify jobs as either
    #   jobs:
    #     install:
    #       - redis
    #       - mysql
    #   OR
    #   jobs:
    #     install:
    #       redis:
    #       mysql:
    #
    def sanitize_jobs(type)
      return nil if @config["jobs"][type].nil?

      jobs = {}
      config_jobs = @config["jobs"][type]
      config_jobs.each do |element|
        case element
        when String
          jobs[element] = nil
        when Hash
          if element.length > 1
           puts "Bad input, #{element.pretty_inspect} should have only one key, please fix your yaml file."
           exit 1
          end
          element.each do |job, properties|
            jobs[job] = properties.nil? ? nil : properties.dup
          end
        else
          puts "Unsupported type for Installed or Install job #{element}"
          exit 1
        end
      end

      # validate jobs
      given_jobs = Set.new(jobs.keys)
      if (intersect = @valid_jobs.intersection(given_jobs)) != given_jobs
        puts "Input Error: Please provide valid #{type} jobs, following jobs are not recognized\n#{(given_jobs - intersect).pretty_inspect}"
        exit 1
      end

      jobs
    end

    def detect_duplicate_jobs
      if !@config["jobs"]["install"].nil? && !@config["jobs"]["installed"].nil?
        install_jobs = Set.new(@config["jobs"]["install"].keys)
        installed_jobs = Set.new(@config["jobs"]["installed"].keys)
        common = install_jobs.intersection(installed_jobs)
        unless common.empty?
          puts "Input error, The following jobs are specified in both the install and installed list.\n#{common.pretty_inspect}"
          exit 1
        end
      end
    end

    def validate_properties(jobs, required_properties)
      return if jobs.nil?

      missing_keys = {}
      jobs.each do |job, properties|
        # Check if this job needs properties
        next if required_properties[job].nil?

        expected = Set.new(required_properties[job])
        given = properties.nil? ? Set.new : Set.new(properties.keys)

        # Check if all the required properties are given
        if !expected.subset?(given)
          missing_keys[job] ||= []
          missing_keys[job] << (expected - given).to_a
        end
      end

      if !missing_keys.empty?
        puts "Input Error: The following mandatory job properties are missing #{missing_keys.pretty_inspect}"
        exit 1
      end
    end

    # Gets called by rake tasks for each job.
    # The possibilities for each job are as follows.
    # 1. It is already installed
    # 2. It is in the install list
    # 3. It is not on the install list or the installed list
    #
    # Case 1, propogate the properties of the installed job to the spec
    # so dependent jobs can use these properties.
    # Case 2, add the required chef role to the chef run list, add default/given
    # properties to the spec
    # Case 3, is a dependecy failure.
    def install(job)
      unless @all_install
        if !@config["jobs"]["installed"].nil? && !@config["jobs"]["installed"][job].nil?
          @spec[job] = @config["jobs"]["installed"][job].dup
          return
        end

        unless @config["jobs"]["install"].has_key?(job) || SYSTEM_JOB.include?(job)
          puts "Dependecy check error: job #{job} is needed by one of the jobs in the install list, please add job #{job} to the install or installed list"
          exit 1
        end

        if !@config["jobs"]["install"][job].nil?
          @spec[job] = @config["jobs"]["install"][job].dup
        end
      end

      # Prepare the run list for this job
      if RUN_COMPONENTS.has_key?(job)
        case RUN_COMPONENTS[job]
        when String
          @run_list << RUN_COMPONENTS[job]
        when Array
          RUN_COMPONENTS[job].each do |component|
            @run_list << component
          end
        end
      end

      @roles << job
    end

    def process_jobs
      # Default to all jobs
      if @config["jobs"].nil?
        # Install all jobs
        @all_install = true
        Rake.application[ALL].invoke
        return
      end

      # Make sure that the "install" and "installed" jobs specified are valid
      @config["jobs"]["install"] = sanitize_jobs("install")
      @config["jobs"]["installed"] = sanitize_jobs("installed")

      if @config["jobs"]["install"].nil?
        puts "You have not selected any jobs to install."
        exit 0
      end

      # Make sure that the "install" and "installed" jobs do not intersect
      detect_duplicate_jobs

      if @config["jobs"]["install"].include?("all")
        # Install all jobs
        if !@config["jobs"]["installed"].nil?
          puts "Please correct your config file. You are trying to install all jobs, but you have also specified an 'installed' section"
          exit 1
        end

        if @config["jobs"]["install"].length != 1
          puts "Please correct your config file. You are trying to install all jobs, remove all other jobs from the 'install' list"
          exit 1
        end

        @all_install = true
        Rake.application[ALL].invoke
        return
      end

      # Sanity check the given properties
      validate_properties(@config["jobs"]["installed"], INSTALLED_JOB_PROPERTIES)
      validate_properties(@config["jobs"]["install"], INSTALL_JOB_PROPERTIES)

      # Let the install rake task do the dependency management
      @config["jobs"]["install"].keys.each do |job|
        Rake.application[job].invoke
      end
    end

    def go(config)
      @spec = {}
      @roles = []
      @run_list = Set.new
      @valid_jobs = Set.new(JOBS)
      @config = config.dup
      @all_install = false

      # Load the job dependecies
      Rake.application.rake_require("job_dependency")

      process_jobs

      # All dependencies are resolved, return the job property spec, chef
      # roles and the vcap run list
      return @spec, @roles, @run_list.to_a
    end
  end
end
