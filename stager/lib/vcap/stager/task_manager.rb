require 'vcap/logging'

require 'vcap/stager/secure_user_manager'
require 'vcap/stager/task'

module VCAP
  module Stager
  end
end

class VCAP::Stager::TaskManager
  attr_accessor :max_active_tasks, :user_mgr, :varz

  def initialize(max_active_tasks, user_mgr=nil, varz={})
    @max_active_tasks = max_active_tasks
    @event_callbacks  = {}
    @queued_tasks     = []
    @active_tasks     = {}
    @user_mgr         = user_mgr
    @logger           = VCAP::Logging.logger('vcap.stager.task_manager')
    @varz             = varz
  end

  def num_tasks
    @queued_tasks.length + @active_tasks.size
  end

  # Adds a task to be performed at some point in the future.
  #
  # @param  task  VCAP::Stager::Task
  def add_task(task)
    @logger.info("Queueing task, task_id=#{task.task_id}")
    @queued_tasks << task
    start_tasks
  end

  # @param  blk  Block  Invoked when there are no active or queued tasks. Should have arity 0.
  def on_idle(&blk)
    @event_callbacks[:idle] = blk
    event(:idle) if num_tasks == 0
  end

  private

  def start_tasks
    while (@queued_tasks.length > 0) && (@active_tasks.size < @max_active_tasks)
      task = @queued_tasks.shift
      task.user = @user_mgr.checkout_user if @user_mgr
      @active_tasks[task.task_id] = task
      @logger.info("Starting task, task_id=#{task.task_id}")
      task.perform {|result| task_completed(task, result) }
    end
    @varz[:num_pending_tasks] = @queued_tasks.length
    @varz[:num_active_tasks] = @active_tasks.size
  end

  def task_completed(task, result)
    @logger.info("Task, id=#{task.task_id} completed, result='#{result}'")

    @active_tasks.delete(task.task_id)
    event(:task_completed, task, result)
    event(:idle) if num_tasks == 0

    if task.user
      cmd = "sudo -u '##{task.user[:uid]}' pkill -9 -U #{task.user[:uid]}"
      VCAP::Stager::Util.run_command(cmd) do |res|
        # 0 : >=1 process matched
        # 1 : no process matched
        # 2 : error
        if res[:status].exitstatus < 2
          @user_mgr.return_user(task.user)
        else
          # Don't return the user to the pool. We have possibly violated the invariant
          # that no process belonging to the user is running when it is returned to
          # the pool.
          @logger.warn("Failed killing child processes for user #{task.user[:uid]}")
          @logger.warn("Command '#{cmd}' exited with status #{res[:status]}")
          @logger.warn("stdout = #{res[:stdout]}")
          @logger.warn("stderr = #{res[:stderr]}")
        end
        start_tasks
      end
    else
      start_tasks
    end
  end

  def event(name, *args)
    cb = @event_callbacks[name]
    return unless cb
    cb.call(*args)
  end

end
