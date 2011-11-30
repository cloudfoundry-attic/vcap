require "fileutils"

fail unless Kernel.const_defined?(:PATH)

FileUtils.mkdir_p(File.join(PATH, "rootfs"))
FileUtils.mkdir_p(File.join(PATH, "union"))

def union_branch_opts
  # Figure out branch option to pass to mount
  ancestors = Dir[File.join(PATH, "../*")].
    find_all { |e| File.directory?(e) }.
    map { |e| File.basename(e) }.
    sort

  # Compile list of ancestors for current PATH. If PATH starts with "." it is not
  # a part of the inheritance chain itself and should unionize the full chain.
  unless File.basename(PATH).start_with?(".")
    ancestors = ancestors.take_while { |e|
      e < File.basename(PATH)
    }
  end

  branches_ro = ancestors.reverse.map { |e| "../%s/rootfs" % e }
  branches_rw = [ "rootfs" ]
  branch_opts = [
    branches_rw.map { |e| "%s=rw" % e },
    branches_ro.map { |e| "%s=ro+wh" % e },
  ].flatten.join(":")
end

def union_mount_command
  "mount -t aufs -o br:#{union_branch_opts} none union"
end

Dir.chdir(PATH) do
  unless system(union_mount_command)
    fail "Unable to mount union..."
    exit 1
  end
end

at_exit do
  if File.directory?(PATH)
    Dir.chdir(PATH) do
      system("umount union")
    end
  end
end
