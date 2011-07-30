#!/usr/bin/env ruby
require 'rake'
require 'yaml'
require 'set'
require 'pp'

$LOAD_PATH.unshift(File.dirname(__FILE__))

class JobManager
  ALL = "all"
  NATS = "nats"
  ROUTER = "router"
  CC = "cloud_controller"
  CF = "cloudfoundry"
  HM = "health_manager"
  DEA = "dea"
  CCDB = "ccdb"
  CCDB_POSTGRES = "ccdb_postgres"
  CCDB_MYSQL = "ccdb_mysql"
  MYSQL_GWY = "mysql_gateway"
  MYSQL_NODE = "mysql_node"
  REDIS_GWY = "redis_gateway"
  REDIS_NODE = "redis_node"
  MONGO_GWY = "mongodb_gateway"
  MONGO_NODE = "mongodb_node"
  RABBIT_GWY = "rabbit_gateway"
  RABBIT_NODE = "rabbit_node"
  REDIS = "redis"
  MYSQL = "mysql"
  MONGODB = "mongodb"
  POSTGRESQL = "postgresql"
  MANDATORY_PROPERTY = "cf_mandatory_property"

  # All supported jobs
  JOBS = [NATS, ROUTER, CF, CC, HM, DEA, CCDB, REDIS, MYSQL, MONGODB, POSTGRESQL]

  SYSTEM_JOB = [CF]

  # List of the required properties and their default values
  JOB_PROPERTIES = {NATS => {"net" => "localhost", "port" => "4222",
                             "user" => "nats", "password" => "nats"},
                    CC =>   {"uri" => "api.vcap.me",
                             "builtin_services" => MANDATORY_PROPERTY},
                    CCDB => {"host" => "localhost", "dbname" => "cloudcontroller", "port" => "5432",
                             "user" => "postgres", "password" => "postgres", "adapter" => "postgres"},
                    MYSQL => {"server_root_password" => "root", "bind_address" => "127.0.0.1"},
                    POSTGRESQL => {"server_root_password" => "root"}}

  # List of supported services
  SERVICES = [REDIS, MYSQL, MONGODB, POSTGRESQL]


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

    def validate_properties(jobs, missing_keys_ok=false)
      return if jobs.nil?

      missing_keys = {}
      missing_mandatory_keys = {}
      bad_keys = {}
      jobs.each do |job, properties|
        # Check if this job needs properties
        if JOB_PROPERTIES[job].nil?
          next if properties.nil?
          bad_keys[job] ||= []
          bad_keys[job] << properties.keys
          next
        end

        expected = Set.new(JOB_PROPERTIES[job].keys)
        given = properties.nil? ? Set.new : Set.new(properties.keys)

        # Check if we recognize all the given properties
        if !given.nil? && !given.subset?(expected)
          bad_keys[job] ||= []
          bad_keys[job] << (given - expected).to_a
        end

        # Check if all the required properties are given
        if !expected.subset?(given)
          missing_keys[job] ||= []
          missing_keys[job] << (expected - given).to_a
        end

        # Verify mandatory properties
        mandatory_properties = Set.new
        JOB_PROPERTIES[job].map do |k, v|
          mandatory_properties << k if v == MANDATORY_PROPERTY
        end
        if !mandatory_properties.subset?(given)
          missing_mandatory_keys[job] ||= []
          missing_mandatory_keys[job] << (mandatory_properties - given).to_a
        end
      end

      if !bad_keys.empty?
        puts "Input Error: The following job properties are not recognized #{bad_keys.pretty_inspect}"
        exit 1
      end
      if !missing_keys_ok && !missing_keys.empty?
        puts "Input Error: The following job properties are mandatory and need to be specified #{missing_keys.pretty_inspect}"
        exit 1
      end
      if !missing_mandatory_keys.empty?
        puts "Input Error: The following mandatory job properties are missing #{missing_mandatory_keys.pretty_inspect}"
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
      if !@config["jobs"]["installed"].nil? && @config["jobs"]["installed"].has_key?(job)
        unless JOB_PROPERTIES[job].nil?
          @spec[job] = @config["jobs"]["installed"][job].dup
        end
        return
      end

      unless @config["jobs"]["install"].has_key?(job) || SYSTEM_JOB.include?(job)
        puts "Dependecy check error: job #{job} is needed by one of the jobs in the install list, please add job #{job} to the install or installed list"
        exit 1
      end

      unless JOB_PROPERTIES[job].nil?
        default_properties = JOB_PROPERTIES[job].dup
        given_properties = @config["jobs"]["install"][job].nil? ? {} : @config["jobs"]["install"][job].dup
        given_properties = default_properties.merge(given_properties)
        @spec[job] = given_properties
      end

      if SERVICES.include?(job)
        @services << job
      end
      @roles << job
    end

    def go(config)
      @spec = {}
      @roles = []
      @services = []
      @valid_jobs = Set.new(JOBS)
      @config = config.dup

      # Load the job dependecies
      Rake.application.rake_require("job_dependency")

      # Default to all jobs
      if @config["jobs"].nil?
        # Install all jobs
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

        Rake.application[ALL].invoke
        return
      end

      # Sanity check the given properties
      validate_properties(@config["jobs"]["installed"])
      validate_properties(@config["jobs"]["install"], true)

      # Let the install rake task do the dependency management
      @config["jobs"]["install"].keys.each do |job|
        Rake.application[job].invoke
      end

      # All dependencies are resolved, return the job property spec, the chef
      # roles and services that should be deployed
      return @spec, @roles, @services
    end
  end
end
