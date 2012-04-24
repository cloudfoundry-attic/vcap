require "readline"
require "shellwords"
require "warden/client"
require "json"

module Warden
  class Repl

    COMMAND_LIST = ['ping', 'create', 'stop', 'destroy', 'spawn', 'link',
                    'run', 'net', 'limit', 'info', 'list','copy', 'help']

    HELP_MESSAGE =<<-EOT
ping                          - ping warden
create [OPTION OPTION ...]    - create container, optionally pass options.
destroy <handle>              - shutdown container <handle>
stop <handle>                 - stop all processes in <handle>
spawn <handle> cmd            - spawns cmd inside container <handle>, returns #jobid
link <handle> #jobid          - do blocking read on results from #jobid
run <handle>  cmd             - short hand for link(spawn(cmd)) i.e. runs cmd, blocks for result
list                          - list containers
info <handle>                 - show metadata for container <handle>
limit <handle> mem  [<value>] - set or get the memory limit for the container (in bytes)
net <handle> #in              - forward port #in on external interface to container <handle>
net <handle> #out <address[/mask][:port]> - allow traffic from the container <handle> to address <address>
copy <handle> <in|out> <src path> <dst path> [ownership opts] - Copy files/directories in and out of the container
help                          - show help message

---

The OPTION argument for `create` can be one of:
  * bind_mount:HOST_PATH,CONTAINER_PATH,ro|rw
      e.g. create bind_mount:/tmp/,/home/vcap/tmp,ro
  * grace_time:SECONDS
      e.g. create grace_time:300
  * disk_size_mb:SIZE
      e.g. create disk_size_mb:512

Please see README.md for more details.
EOT

    def initialize(opts={})
      @trace = opts[:trace] == true
      @warden_socket_path = opts[:warden_socket_path] || "/tmp/warden.sock"
      @client = Warden::Client.new(@warden_socket_path)
      @history_path = opts[:history_path] || File.join(ENV['HOME'], '.warden-history')
    end

    def run
      restore_history

      @client.connect unless @client.connected?

      comp = proc { |s|
        if s[0] == '0'
          container_list.grep( /^#{Regexp.escape(s)}/ )
        else
          COMMAND_LIST.grep( /^#{Regexp.escape(s)}/ )
        end
      }

      Readline.completion_append_character = " "
      Readline.completion_proc = comp

      while line = Readline.readline('warden> ', true)
        if process_line(line)
          save_history
        end
      end
    end

    def container_list
      @client.write(['list'])
      JSON.parse(@client.read.inspect)
    end

    def save_history
      marshalled = Readline::HISTORY.to_a.to_json
      open(@history_path, 'w+') {|f| f.write(marshalled)}
    end

    def restore_history
      return unless File.exists? @history_path
      open(@history_path, 'r') do |file|
        history = JSON.parse(file.read)
        history.map {|line| Readline::HISTORY.push line}
      end
    end

    def make_create_config(args)
      config = {}

      return config if args.nil?

      args.each do |arg|
        head, tail = arg.split(":", 2)

        case head
        when "bind_mount"
          src, dst, mode = tail.split(",")
          config["bind_mounts"] ||= []
          config["bind_mounts"].push [src, dst, { "mode" => mode }]
        when "grace_time"
          config["grace_time"] = tail
        when "disk_size_mb"
          config["disk_size_mb"] = tail
        else
          raise "Unknown argument: #{head}"
        end
      end

      config
    end

    def process_line(line)
      words = Shellwords.shellwords(line)
      return nil if words.empty?

      command_info = {
        :name   => words[0],
        :args   => words.slice(1, words.length - 1),
      }

      puts "+ #{line}" if @trace

      case words[0]
      when 'run', 'spawn'
        #coalesce shell commands into a single string
        if words.size > 3
          tail = words.slice!(2..-1)
          words.push(tail.join(' '))
        end
      when 'create'
        create_args = words.slice(1, words.length - 1)
        begin
          words = ['create', make_create_config(create_args)]
        rescue => e
          puts "Error: #{e}"
          return command_info
        end
      end

      if words[0] == 'help'
        puts HELP_MESSAGE
        return command_info
      end

      @client.connect() unless @client.connected?
      @client.write(words)
      begin
        raw_result = @client.read.inspect
        # Brutal hack to work around the fact that JSON refuses
        # to parse simple strings.
        x = JSON.parse("[#{raw_result}]")
        command_info[:result] = x[0]
        case words[0]
        when 'create'
          puts command_info[:result]
        when 'run'
          status, stdout, stderr = command_info[:result]
          puts "exit status: #{status}"
          puts
          puts "stdout:"
          puts stdout
          puts
          puts "stderr:"
          puts stderr
          puts
        else
          puts raw_result
        end
      rescue  => e
        command_info[:error] = e
        if e.message.match('unknown command')
          puts "#{e.message}, try help for assistance."
        else
          puts e.message
        end
      end

      command_info
    end

  end
end
