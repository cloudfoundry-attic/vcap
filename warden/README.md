# warden

`warden` is a daemon that is responsible for managing throw-away Linux
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

    root
    ├── .instance-skeleton
    ├── .lib
    ├── 000-base
    ├── 001-apt
    ├── ....
    ├── create.sh
    └── setup.rb

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

`warden` runs on EventMachine. It uses the Redis protocol to communicate with
the outside world, and does so over a Unix socket, which is located at
`/tmp/warden.sock` by default. The daemon can respond to a number of verbs,
that either create new containers, modify container state, or run scripts
inside of a container.  The verbs that `warden` responds to are:

* `create`: This creates a new container. In the future this verb may accept an
  optional configuration parameter. This command returns handle (or name) of
  the container which is used to identify it. The handle is equal to the
  hexadecimal representation of its IP address, as acquired from the pool of
  unused network addresses in the configured subnet.
* `run <handle> <script>`: This command runs the specified script in the
  container identified by the specified handle. It returns a 3-element tuple
  containing the exit status, the path to the file containing STDOUT, and the
  path to the file containing STDERR of the script. **Note**: because `warden`
  captures the output of scripts and only returns after the script has
  completed, long running tasks should be backgrounded.
* `destroy <handle>`: This command destroys the container identified by the
  specified handle. It first stops the container when it is still running,
  thereby terminating any running scripts, before destroying the container and
  its associated directories. Because everything related to the container is
  destroyed, artifacts from running an earlier script should be copied out
  before calling `destroy`.

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

An unused subnet is allocated whenever a container is created. The pool where
subnets are allocated from is configured in `lib/warden/server.rb` right now,
and will be made configurable in the future (**TODO**).

# System prerequisites

`warden` is only tested on Ubuntu 10.04 with a backported kernel, but should
also work on later Ubuntu versions. Before running `warden`, the following
packages need to be installed:

* linux-image-server-lts-backport-natty
* debootstrap
* lxc-tools

Before containers can be started, the `cgroup` file system should be mounted.
This is done when `warden` is started, unless it is already mounted.

# Hacking

The packaged tests create and destroy actual containers, so require system
prerequisites to be in place. They need to be run as root (or any other user
than can work with lxc-tools).

Setting up the base system is done by running `setup.rb` in the `root/`
directory. This script loops over the subdirectories not starting with a `.`
alphabetically and runs their `setup.rb`.

Quickly creating a container to see if the (changed) configuration works can be
done using the `create.sh` script in the `root/` directory.
