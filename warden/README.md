# warden

A framework for managing isolated and resource controlled environments.

## Introduction

The project's primary goal is to provide a simple API for managing
isolated environments. These isolated environments -- or _containers_ --
can be limited in terms of CPU usage, memory usage, disk usage, and
network access. As of writing, the only supported OS is Linux.

## Getting Started

This short guide assumes Ruby 1.9 and Bundler are already available.

#### Install the right kernel

If you are running Ubuntu 10.04 (Lucid), make sure the backported Natty
kernel is installed. After installing, reboot the system before
continuing.

```
sudo apt-get install -y linux-image-generic-lts-backport-natty
```

#### Install dependencies

```
sudo apt-get install -y build-essential debootstrap
```

#### Setup Warden

Run the setup routine, which compiles the C code bundled with Warden and
sets up the base file system for Linux containers.

```
sudo bundle exec rake setup
```

**NOTE**: if `sudo` complains that `bundle` cannot be found, try `sudo
env PATH=$PATH` to pass your current `PATH` to the `sudo` environment.

#### Run Warden

```
sudo bundle exec rake warden:start[config/linux.yml]
```

#### Interact with Warden

```
bundle exec bin/warden-repl
```

## Implementation for Linux

Isolation is achieved by namespacing kernel resources that would
otherwise be shared. The intended level of isolation is set such that
multiple containers present on the same host should not be aware of each
others presence. This means that these containers are given (among
others) their own PID (Process ID) namespace, network namespace, and
mount namespace.

Resource control is done by using [Control Groups][cgroups]. Every
container is placed in its own control group, where it is configured
to use an equal slice of CPU compared to other containers, and the
maximum amount of memory it may use.

[cgroups]: http://kernel.org/doc/Documentation/cgroups/cgroups.txt

The following sections give a brief summary of the techniques used to
implement the Linux backend for Warden. A more detailed description can
be found in the `root/linux` directory of this repository.

### Networking

Every container is assigned a network interface which is one side of a
virtual ethernet pair created on the host. The other side of the virtual
ethernet pair is only visible on the host (from the root namespace).
The pair is configured to use IPs in a small and static subnet. Traffic
from and to the container can be forwarded using NAT. Additionally, all
traffic can be filtered and shaped as needed, using readily available
tools such as `iptables`.

### Filesystem

Every container gets a private root filesystem. This filesystem is
created by stacking a read-only filesytem and a read-write filesystem.
This is implemented by using `aufs` on Ubuntu versions from 10.04 up to
11.10, and `overlayfs` on Ubuntu 12.04.

The read-only filesystem contains the minimal set of Ubuntu packages and
Warden-specific modifications common to all containers. The read-write
filesystem stores files overriding container-specific settings when
necessary. Because all writes are applied to the read-write filesystem,
containers can share the same read-only base filesystem.

The read-write filesystem is created by formatting a large sparse file.
Because the size of this file is fixed, the filesystem that it contains
cannot grow beyond this initial size.

### Difference with LXC

The _Linux Containers_ or _LXC_ project has goals that are similar to
those of Warden; isolation and resource control. They both use the same
Linux kernel primitives to achieve their goals. In fact, early versions
of Warden even **used LXC**.

The major difference between the two projects is that LXC is explicitly
tied to Linux, where Warden backends can be implemented for any
operating system that implements some way of isolating environments.
It is a daemon that manages containers and can be controlled via a
simple API rather than a set of tools that are individually executed.

While the Linux backend for Warden was initially implemented with LXC,
the current version no longer depends on it. During development, we
found that running LXC out of the box is a very opaque and static
process. There is little control over when different parts of the
container start process are executed, and how they relate to each other.
Because Warden relies on a very small subset of the functionality that
LXC offers, we decided to create a tool that only implements the
functionality we need in under 1k LOC of C code. This tool executes
preconfigured hooks at different stages of the container start process,
such that required resources can be set up without worrying about
concurrency issues. These hooks make the start process more transparent,
allowing for easier debugging when parts of this process are not working
as expected.

## Container Lifecycle

The entire lifecyle of containers is managed by Warden. The API allows
users to create, configure, use, and destroy containers. Additionally,
it can automatically clean up unused containers when needed.

### Create

Every container is identified by its _handle_, which is returned by
Warden upon creating it. It is a hexadecimal representation of the IP
address that is allocated for the container. Regardless of whether the
backend providing the container functionality supports networking or
not, an IP address will be allocated by Warden to identify a container.

When a container was created and its handle was returned to the caller,
it is immediately ready for use. All resources will be allocated, the
necessary processes will be started and all firewalling tables will have
been updated.

If Warden is configured to clean up containers after activity, it will
use the number of connections that have referenced the container as a
metric to determine inactivity. If the number of connections referencing
the container drops to zero, the container will automatically be
destroyed after a preconfigured interval. If in the mean time the
container is referenced again, this timer is cancelled.

### Use

The container can be used by running arbitrary scripts, copying files in
and out, modifying firewall rules and modifying resource limits. A
complete list of operations is discussed under "Interface".

### Destroy

When a container is destroyed -- either per user request, or
automatically after being idle -- Warden first kills all unprivileged
processes running inside the container. These processes first receive a
`TERM` signal followed by a `KILL` if they haven't exited after a couple
of seconds. When these processes have terminated, the root of the
container's process tree is sent a `KILL`. Once all resources the
container used have been released, its files are removed and it is
considered destroyed.

## Networking


## Interface

Warden uses a line-based JSON protocol to communicate with its clients,
and does so over a Unix socket which is located at `/tmp/warden.sock` by
default. Every command invocation is formatted as a JSON array, where
the first element is the command name and subsequent elements can be any
JSON object. The commands it responds to are as follows:

### `create [CONFIG]`

Creates a new container.

Returns the handle of the container which is used to identify it.

The optional `CONFIG` parameter is a hash that specifies configuration
options used during container creation. The supported options are:

#### `bind_mounts`

If supplied, this specifies a set of paths to be bind mounted inside the
container. The value must be an array. The elements in this array
specify the bind mounts to execute, and are executed in order. Every
element must be of the form:

```
[
  # Path in the host filesystem
  "/host/path",

  # Path in the container
  "/path/in/container",

  # Optional hash with options. The `mode` key specifies whether the bind
  # mount should be remounted as `ro` (read-only) or `rw` (read-write).
  {
    "mode" => "ro|rw"
  }
]
```

#### `grace_time`

If specified, this setting overrides the default time of a container not
being referenced by any client until it is destroyed. The value can
either be the number of seconds as floating point number or integer, or
the `null` value to completely disable the grace time.

#### `disk_size_mb`

If specified, this setting overrides the default size of the container's
scratch filesystem. The value is expected to be an integer number.

### `spawn HANDLE SCRIPT`

Run the script `SCRIPT` in the container identified by `HANDLE`.

Returns a job identifier that can be used to reap its exit status at
some point in the future. Also, the connection that issued the command
may go away and reconnect later while still being able to reap the job.

### `link HANDLE JOB_ID`

Reap the script identified by `JOB_ID`, running in the container
identified by `HANDLE`.

Returns a 3-element tuple containing the integer exit status, a string
containing its `STDOUT` and a string containing its `STDERR`. These
elements may be `null` when they cannot be determined (e.g. the
script couldn't be executed, was killed, etc.).

### `limit HANDLE (mem) [VALUE]`

Set or get resource limits for the container identified by `HANDLE`.

The following resources can be limited:

* The memory limit is specified in number of bytes. It is enforced using
  the control group associated with the container. When a container
  exceeds this limit, one or more of its processes will be killed by the
  kernel. Additionally, the Warden will be notified that an OOM happened
  and it subsequently tears down the container.

### `net HANDLE in`

Forward a port on the external interface of the host to the container
identified by `HANDLE`.

Returns the port number that is mapped to the container. This port
number is the same on the inside of the container.

### `net HANDLE out ADDRESS[/MASK][:PORT]`

Allow traffic from the container identified by `HANDLE` to the network
address specified by `ADDRESS`. Additionally, the address may be masked
to allow a network of addresses, and a port to only allow traffic to a
specific port.

Returns `ok`.

### `copy HANDLE in SRC_PATH DST_PATH`

Copy the contents at `SRC_PATH` on the host to `DST_PATH` in the
container identified by `HANDLE`.

Returns `ok`.

File permissions and symbolic links will be preserved, while hardlinks
will be materialized. If `SRC_PATH` contains a trailing `/` only the
contents of the directory will be copied. Otherwise, the outermost
directory, along with its contents, will be copied. The unprivileged
user will be the owner of the files in the container.

### `copy HANDLE out SRC_PATH DST_PATH [OWNER]`

Copy the contents at `SRC_PATH` in the container identified by `HANDLE`
to `DST_PATH` on the host.

Returns `ok`.

Its semantics are identical to `copy HANDLE in` except in respect
to file ownership. By default, the files on the host will be owned by
root. If the `OWNER` argument is supplied (in the form of `USER:GROUP`),
files on the host will be chowned to this user/group after the copy has
completed.

### `stop HANDLE`

Stop processes running inside the container identified by `HANDLE`.

Returns `ok`.

Because all processes are taken down, unfinished scripts will likely
terminate without an exit status being available.

### `destroy HANDLE`

Stop processes and destroy all resources associated with the container
identified `HANDLE`.

Returns `ok`.

Because everything related to the container is destroyed, artifacts from
running an earlier script should be copied out before calling `destroy`.

## Configuration

Warden can be configured by passing a configuration file when it is
started. An example configuration is located at `config/linux.yml` in
the repository.

## System prerequisites

Warden runs on Ubuntu 10.04 and higher.

A backported kernel needs to be installed on 10.04. This kernel is
available as `linux-image-server-lts-backport-natty` (substitute
`server` for `generic` if you are running Warden on a desktop variant of
Ubuntu 10.04).

Other dependencies are:

* build-essential (for compiling Warden's C bits)
* debootstrap (for bootstrapping the container's base filesystem)

Further bootstrapping of Warden can be done by running `rake setup`.

## Hacking

The included tests create and destroy real containers, so require system
prerequisites to be in place. They need to be run as root if the backend
to be tested requires it.

See `root/<backend>/README.md` for backend-specific information.
