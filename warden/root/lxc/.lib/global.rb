require "fileutils"

def mount_union_command(base_path = nil)
  base_path ||= File.expand_path("..", $0)

  FileUtils.mkdir_p(File.join(base_path, "rootfs"))
  FileUtils.mkdir_p(File.join(base_path, "union"))

  # Figure out branch option to pass to mount
  ancestors = Dir[File.join(base_path, "../*")].
    find_all { |e| File.directory?(e) }.
    map { |e| File.basename(e) }.
    sort

  # Compile list of ancestors for current PATH. If PATH starts with "." it is not
  # a part of the inheritance chain itself and should unionize the full chain.
  unless File.basename(base_path).start_with?(".")
    ancestors = ancestors.take_while { |e|
      e < File.basename(base_path)
    }
  end

  branches_ro = ancestors.reverse.map { |e| "../%s/rootfs" % e }
  branches_rw = [ "rootfs" ]
  branch_opts = [
    branches_rw.map { |e| "%s=rw" % e },
    branches_ro.map { |e| "%s=ro+wh" % e },
  ].flatten.join(":")

  "mount -t aufs -o br:#{branch_opts} none union"
end

def mount_union(base_path = nil)
  base_path ||= File.expand_path("..", $0)

  command = mount_union_command(base_path)

  Dir.chdir(base_path) do
    system(command)
  end

  at_exit do
    Dir.chdir(base_path) do
      system("umount union")
    end
  end
end

def error(msg)
  STDOUT.puts
  STDOUT.puts msg
  STDOUT.puts

  exit 1
end

def chroot(path, script = nil)
  args = [
    ["chroot", path],
    ["env", "-i"],
    ["/bin/bash"] ]
  options = {}
  r, w = IO.pipe

  if script
    # Explicitly load and export PATH from /etc/environment because Bash expect
    # it to be set by its calling process (init, getty, sshd, etc), but starts
    # with an empty environment here.
    script = <<-EOS + script
      . /etc/environment
      export PATH
    EOS

    args << ["-c", script]
    options[:out] = w
  end

  pid = spawn(*args.flatten, options)
  Process.waitpid(pid)

  if script
    unless $?.exitstatus == 0
      raise "non-zero exit status"
    end

    # Return stdout
    w.close
    r.read
  end

ensure
  r.close rescue nil
  w.close rescue nil
end

def script(str)
  args = ["/bin/bash", "-c", str.to_s]
  system(*args)
end

def sh(str)
  script(str)
end

def write(file, body)
  FileUtils.mkdir_p(File.dirname(file))
  File.open(file, "w") do |f|
    f.write(body)
  end
end
