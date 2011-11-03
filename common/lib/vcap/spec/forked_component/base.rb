require 'vcap/common'


module VCAP
  module Spec
    module ForkedComponent
    end
  end
end

class VCAP::Spec::ForkedComponent::Base
  attr_reader :pid, :pid_filename, :output_basedir, :name, :cmd

  attr_accessor :reopen_stdio

  # @param  cmd             String  Command to run
  # @param  name            String  Short name for this component (e.g. 'redis')
  # @param  output_basedir  String  Stderr/stdout will be placed under this directory
  # @param  pid_filename    String  If not nil, we ready the pid from this file instead
  #                                 of using the pid returned from fork
  def initialize(cmd, name, output_basedir='/tmp', pid_filename=nil)
    @cmd  = cmd
    @name = name
    @output_basedir = output_basedir
    @pid_filename   = pid_filename

    @reopen_stdio = true

  end

  def start
    pid = fork do

      if @reopen_stdio
        fn = File.join(@output_basedir, "#{@name}.#{Process.pid}.out")
        outfile = File.new(fn, 'w+')
        $stderr.reopen(outfile)
        $stdout.reopen(outfile)
      end

      exec(@cmd)
    end

    if @pid_filename
      wait_for(5) { File.exists?(@pid_filename) }
      @pid = File.read(@pid_filename).chomp.to_i
    else
      @pid = pid
    end

    self
  end

  def stop
    return unless @pid && VCAP.process_running?(@pid)
    Process.kill('TERM', @pid)
    Process.waitpid(@pid, 0)
    FileUtils.rm_f(@pid_filename) if @pid_filename
    @pid = nil

    self
  end

  def running?
    VCAP.process_running?(@pid)
  end

  def ready?
    raise NotImplementedError
  end

  def wait_ready(timeout=1)
    wait_for { ready? }
  end

  private

  def wait_for(timeout=1, &predicate)
    start = Time.now()
    cond_met = predicate.call()
    while !cond_met && ((Time.new() - start) < timeout)
      cond_met = predicate.call()
      sleep(0.2)
    end
    cond_met
  end
end
