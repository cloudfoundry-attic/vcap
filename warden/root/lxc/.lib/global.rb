$:.unshift File.expand_path("..", __FILE__)
require "fileutils"
require "mount_union"

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

  if script
    # Explicitly load and export PATH from /etc/environment because Bash expect
    # it to be set by its calling process (init, getty, sshd, etc), but starts
    # with an empty environment here.
    script = <<-EOS + script
      . /etc/environment
      export PATH
    EOS

    args.push ["-c", script]
  end

  unless system(*args.flatten)
    raise "non-zero exit status"
  end
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
