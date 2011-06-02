VMware's Cloud Application Platform
===================================

Copyright (c) 2009-2011 VMware, Inc.

What is Cloud Foundry?
----------------------

Cloud Foundry is an open platform-as-a-service (PaaS). The system supports
multiple frameworks, multiple application infrastructure services and
deployment to multiple clouds.

License
-------

Cloud Foundry uses the Apache 2 license.  See LICENSE for details.

Installation Notes
------------------

Cloud Foundry is made up of a number of system components (cloud controller,
health manager, dea, router, etc.). These components can run co-located in a
single vm/single os or can be spread across several machines/vm's.

For development purposes, the preferred environment is to run all of the core
components within a single vm and then interact with the system from outside of
the vm via an ssh tunnel. The pre-defined domain `*.vcap.me` maps to local host,
so when you use this setup, the end result is that your development environment
is available at [http://api.vcap.me](http://api.vcap.me).

For large scale or multi-vm deployments, the system is flexible enough to allow
you to place system components on multiple vm's, run multiple nodes of a given
type (e.g., 8 routers, 4 cloud controllers, etc.)

The detailed install instructions below walk you through the install process
for a single vm installation.

Versions of these instructions have been used for production deployments, and
for our own development purposes. many of us develop on mac laptops, so some
additional instructions for this environment have been included.

Detailed Install/Run Instructions:
----------------------------------

There are two methods for installing VCAP.  One is a manual process, which you
might choose to do if you want to understand the details of what goes into
a bringing up a VCAP instance. The other is an automated process contributed
by the community. In both cases, you need to start with a stock Ubuntu
server VM.

### Step 1: create a pristine VM with ssh

* setup a VM with a pristine Ubuntu 10.04.2 server 64bit image,
  [download here](http://www.ubuntu.com/download/ubuntu/download)
* you may wish to snapshot your VM now in case things go pear shaped.
* great snapshot spots are here and after step 4
* to enable remote access (more fun than using the console), install ssh.

To install ssh:

    sudo apt-get install openssh-server

#### Step 2: run the automated setup process
Run the install script. It'll ask for your sudo password at the
beginning and towards the end. The entire process takes ~1 hour, so just
keep a loose eye on it.

     sudo apt-get install curl
     bash < <(curl -s -k -B https://github.com/cloudfoundry/vcap/raw/master/setup/install)

NOTE: The automated setup does not auto-start the system. Once you are
done with the setup, exit your current shell, restart a new shell and continue
the following steps

#### Step 3: start the system

    cd ~/cloudfoundry/vcap
    bin/vcap start
    bin/vcap tail  # see aggregate logs

#### Step 4: *Optional, mac users only*, create a local ssh tunnel

From your VM, run `ifconfig` and note your eth0 IP address, which will look something like: `192.168.252.130`

Now go to your mac terminal window and verify that you can connect with SSH:

    ssh <your VM user>@<VM IP address>

If this works, create a local port 80 tunnel:

    sudo ssh -L <local-port>:<VM IP address>:80 <your VM user>@<VM IP address> -N

If you are not already running a local web server, use port 80 as your local port,
otherwise you may want to use 8080 or another common http port.

Once you do this, from both your mac, and from within the vm, `api.vcap.me` and `*.vcap.me`
will map to localhost which will map to your running Cloud Foundry instance.


Trying your setup
-----------------

### Step 5: validate that you can connect and tests pass
#### From the console of your vm, or from your mac (thanks to local tunnel)

    vmc target api.vcap.me
    vmc info

Note: If you are using a tunnel and selected a local port other than 80 you
will need to modify the target to include it here, like `api.vcap.me:8080`.

#### This should produce roughly the following:

    VMware's Cloud Application Platform
    For support visit support@cloudfoundry.com

    Target:   http://api.vcap.me (v0.999)
    Client:   v0.3.10

#### Play around as a user, start with:
    vmc register --email foo@bar.com --passwd password
    vmc login --email foo@bar.com --passwd password

#### To see what else you can do try:
    vmc help

Testing your setup
------------------

Once the system is installed, you can run the following command Basic System
Validation Tests (BVT) to ensure that major functionality is working.

    cd cloudfoundry/vcap
    cd tests && bundle package; bundle install && cd ..
    rake tests

### Unit tests can also be run using the following.

    cd cloud_controller
    rake spec
    cd ../dea
    rake spec
    cd ../router
    rake spec
    cd ../health_manager
    rake spec

### Step 6: you are done, make sure you can run a simple hello world app.

Create an empty directory for your test app (lets call it env), and enter it.

    mkdir env && cd env

Cut and paste the following app into a ruby file (lets say env.rb):

    require 'rubygems'
    require 'sinatra'

    get '/' do
      host = ENV['VMC_APP_HOST']
      port = ENV['VMC_APP_PORT']
      "<h1>XXXXX Hello from the Cloud! via: #{host}:#{port}</h1>"
    end

    get '/env' do
      res = ''
      ENV.each do |k, v|
        res << "#{k}: #{v}<br/>"
      end
      res
    end

#### Create & push a 4 instance version of the test app, like so:
    vmc push env --instances 4 --mem 64M --url env.vcap.me -n

#### Test it in the browser:

[http://env.vcap.me](http://env.vcap.me)

Note that hitting refresh will show a different port in each refresh reflecting the different active instances

#### Check the status of your app by running:

    vmc apps

#### Which should yield the following output:

    +-------------+----+---------+-------------+----------+
    | Application | #  | Health  | URLS        | Services |
    +-------------+----+---------+-------------+----------+
    | env         | 1  | RUNNING | env.vcap.me |          |
    +-------------+----+---------+-------------+----------+
