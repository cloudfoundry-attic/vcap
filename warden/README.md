# warden

`warden` is a daemon that manages throw-away Linux
containers. The containers can be used as scratch-spaces to run arbitrary
scripts as unpriviledged user, not only jailing the file system, but also
jailing the process table and networking interface. The network interface for
every container is a virtual ethernet pair that lives in an isolated subnet.
The host can be configured to NAT traffic from containers to the outside world,
and perform any kind of filtering and monitoring on it using `iptables`.

# Concepts

* **host**: machine running `warden` and the containers it spawn.

# Containers

Every container boots into a fresh base system. This is done by using one or
more read only base file systems that contain enough to boot a container. The
combination of these file systems with a writable per-container file system is
perceived by the container as a single fully writable file system. This union
of file systems is created using `aufs`. Because all write operations to the
resulting file system are persisted in the writable scratch space, all
containers can share the same, read only, base file systems.

## Base file structure

The directory structure in place to build these scratch spaces is located in
the `root/` directory of this repository. Its contents looks like this:

    root/lxc
    ├── 000-base
    ├── 001-apt
    ├── ...
    └── 0??-xxx

The read only file systems are sorted aphabetically when layering one over the
order, so the root of all unions becomes `000-base`, next in line is `001-apt`
and so forth. Note that directories starting with a `.` are not included in
this list.

These directories do not hold the file system they represent directly, but
contain a `setup.rb` script which is responsible for setting up its part of the
file system. When this script is run, it creates a `rootfs` and a `union`
directory. The list of `rootfs` directories of directories in `root/`, that
are aphabetically smaller than the directory where the script is run, is
layered together with this `rootfs` directory and mounted in the `union`
directory. Note that all previous `rootfs` directories are read only, and
writes caused by the setup script end up in the `rootfs` directory. For
instance: when a directory `002-something` is added to `root`, and its
`setup.rb` runs, the `union` directory will layer in order: `001-base/rootfs`
read only, `002-apt/rootfs` read only and `002-something/rootfs` read/write.

## Creating a new container

The skeleton for new containers is located in the `.instance-skeleton`
directory and contains a series of scripts and templates to set up its file
system. New containers do not use this skeleton directly. Rather, the skeleton
is copied to a container-specific directory in the same root (e.g.
`.instance-my_container`) before setting it up.

After copying, the `setup.rb` in the container-specific directory is run and
creates a number of configuration files and scripts. These scripts are used to
start and stop the container. Container-specific configuration, such as its
name and IP address, is pulled from environment variables by `setup.rb` and
cannot be changed later.

# Talking with `warden`

`warden` runs on EventMachine. It uses a line-based JSON protocol to communicate with
the outside world, and does so over a Unix socket, which is located at
`/tmp/warden.sock` by default. The daemon can respond to a number of verbs,
that either create new containers, modify container state, or run scripts
inside of a container. The verbs that `warden` responds to are:

* `create [config]`: This creates a new container. The optional `config`
   parameter is a hash that specifies configuration options used during
   container creation. The supported configuration options are:

   * `bind_mounts`: If supplied, this specifies a set of paths to be bind mounted
   inside the container. The value must be a hash of the form:
   ```
   "/host/path" => {                  # Path in the host filesystem
     "path" => "/path/in/container",  # Path in the container
     "mode" => "ro|rw",               # Optional. Remount the path as ro or rw.
   ```

   This command returns handle (or name) of the container which is used to
   identify it. The handle is equal to the hexadecimal representation of its IP
   address, as acquired from the pool of unused network addresses in the
   configured subnet.

* `spawn <handle> <script>`: Run the Bash script `<script>` in the context of the
  container identified by `<handle>`. This command returns a job
  identifier that can be used to reap its exit status at some point in the
  future. Also, the connection that issued the command may go away and
  reconnect later while still being able to reap the job.

* `link <handle> <job_id>`: Try to reap the script identified by `<job_id>`
  running in the container identified by `<handle>`. When the script is still
  being executed, this command blocks the connection. When the script finishes,
  or has already finished, this command returns a 3-element tuple. This tuple
  contains, in order, the integer exit status, path to the captured STDOUT, and
  the path to the captured STDERR. These elements may be nil when they cannot
  be determined.

* `limit <handle> (mem|disk) [<value>]`: Set or get resource limits for the
  container identified by `<handle>`. The following resources can be limited:

    * The memory limit is specified in number of bytes. It is enforced using
      the control group associated with the container. When a container exceeds
      this limit, one or more of its processes will be killed by the kernel.
      Additionally, the warden will be notified that an OOM happened and it
      subsequently tears down the container.
    * The disk space limit is specified in the number of blocks. It is enforced
      by means of a disk space quota for the user associated with the
      container. When a container exceeds this limit, the warden will be
      notified and it subsequently tears down the container.

* `net <handle> in`: Forward a port on the external interface of the host to
  the container identified by `<handle>`. The port number is the same on the
  outside as it is on the inside of the container. This command returns the
  mapped port number.

* `net <handle> out <address[/mask][:port]>`: Allow traffic from the container
  identified by `<handle>` to the network address specified by `<address>`. The
  address may optionally contain a mask to allow a network of addresses, and a
  port to only allow traffic to that specific port.

* `copy <handle> in <src_path> <dst_path>`: Copy the contents at `<src_path>`
   on the host to `<dst_path>` in the container. File permissions and symbolic
   links will be preserved, while hardlinks will be materialized. If
   `<src_path>` contains a trailing `/` only the contents of the directory will
   be copied. Otherwise, the outermost directory, along with its contents, will
   be copied. The `vcap` user will own the files in the container.

* `copy <handle> out <src_path> <dst_path> [<owner>]`: Copy the contents at
   `<src_path>` in the container to `<dst_path>` on the host. Its semantics are
   identical to `copy <handle> in` except in respect to file ownership. By
   default, the files on the host will be owned by root. If the `<owner>`
   argument is supplied (in the form of `<user>:<group>`), files on the host
   will be chowned to this user/group after the copy has completed.

* `stop <handle>`: Stop processes running inside the container identified by
  the specified handle. Because all processes are taken down, unfinished
  scripts will likely terminate without an exit status being available.

* `destroy <handle>`: Stop processes and destroy all resources associated with
  the container identified by the specified handle. Because everything related
  to the container is destroyed, artifacts from running an earlier script
  should be copied out before calling `destroy`.

## Lifecycle management

Since `warden` thinks of containers as being ephemeral, it includes logic to
clean up containers once they can no longer be used. The lifecycle of a
container is associated with the client connections that reference it. When
some client creates a container and subsequently disconnects, the container is
implicily destroyed. However, when the handle of that container is used by
another client, it only is destroyed once both connections disconnect. This is
done by means of a connection-oriented reference count. Whenever the set of
connections referencing a container becomes empty, it is destroyed. There is no
difference between a container being manually or automatically destroyed.

## Networking

Every container is assigned an individual `/30` subnet. Containers use a
virtual ethernet pair for networking. The host side of the pair is assigned the
`<network>+1` IP address, where the container side is assigned the
`<network>+2` IP address. The subnets are allocated from a pool of available
subnets, which can be configured by the `pool_start_address` and `pool_size`
configuration parameters under the `network` key. The pool consist of
`pool_size` subnets starting with the subnet of `pool_start_address`.

A frequently unused private range of IP addresses is the `172.16.0.0/12` range.

# System prerequisites

`warden` is only tested on Ubuntu 10.04 with a backported kernel, but should
also work on later Ubuntu versions. Before running `warden`, the following
packages need to be installed:

* linux-image-server-lts-backport-natty
* debootstrap

Make sure that no `cgroup` type file system is mounted. The warden mounts this
file system with a specific set of options.

Other dependencies can be compiled and installed by running `rake setup`.

# Hacking

The packaged tests create and destroy actual containers, so require system
prerequisites to be in place. They need to be run as root.

Setting up the base system is done by running `setup.rb` in the `root/lxc/`
directory. This script loops over the subdirectories not starting with a `.`
alphabetically and runs their `setup.rb`.

Quickly creating a container to see if the (changed) configuration works can be
done using the `create.sh` script in the `root/lxc/` directory.
