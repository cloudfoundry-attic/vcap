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
the vm via an ssh tunnel. The pre-defined domain *.vcap.me maps to local host,
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


### step -1: 

* setup a VM with a pristine Ubuntu 10.04.2 server 64bit image, 
  [download here](http://www.ubuntu.com/business/get-ubuntu/download)
* you may wish to snapshot your VM now in case things go pear shaped.
* great snapshot spots are here and after step 4
* to enable remote access (more fun than using the console), install ssh.

     sudo apt-get install openssh-server


### step 0: install system and rvm dependencies 

    sudo apt-get install autoconf curl git-core ruby bison build-essential zlib1g-dev libssl-dev libreadline5-dev

### step 1: install rvm

For detailed rvm install instructions see: [https://rvm.beginrescueend.com/rvm/install/](https://rvm.beginrescueend.com/rvm/install/) or follow the quick steps below.

Install rvm using their script. Note: the -k 
switch is only needed if the certificate validation fails:

    bash < <(curl -s -k -B https://rvm.beginrescueend.com/install/rvm)

Follow the instructions given by the RVM
installer (a copy is included below for your convenience).
    
    # you must complete the install by loading RVM in new shells.
    #
    #
    #  1) Place the folowing line at the end of your shell's loading files
    #     (.bashrc or .bash_profile for bash and .zshrc for zsh),
    #     after all PATH/variable settings:
    #
    #     # This loads RVM into a shell session.
    #     [[ -s \"$rvm_path/scripts/rvm\" ]] && source \"$rvm_path/scripts/rvm\"  
    #
    #     You only need to add this line the first time you install rvm.
    #
    #  2) Ensure that there is no 'return' from inside the ~/.bashrc file,
    #     otherwise rvm may be prevented from working properly.
    #
    #     This means that if you see something like:
    #
    #    '[ -z \"\$PS1\" ] && return'
    #
    #  then you change this line to:
    #
    #  if [[ -n \"\$PS1\" ]] ; then
    #
    #    # ... original content that was below the '&& return' line ...
    #    
    #  fi # <= be sure to close the if at the end of the .bashrc.
    #
    #    # this is a good place to source rvm
    #         [[ -s \"$rvm_path/scripts/rvm\" ]] && source \"$rvm_path/scripts/rvm\"      
    #
    #   <EOF> - this marks the end of the .bashrc
    #
    #     Be absolutely *sure* to REMOVE the '&& return'.
    #
    #     If you wish to DRY up your config you can 'source ~/.bashrc' at the 
    #     bottom of your .bash_profile.
    #
    #     Placing all non-interactive (non login) items in the .bashrc,
    #     including the 'source' line above and any environment settings.
    #
    #  3) CLOSE THIS SHELL and open a new one in order to use rvm.


### step 2: use rvm to install ruby 1.9.2 and make it default

    rvm install 1.9.2-p180 
    rvm --default 1.9.2-p180

### step 3: use rvm to install ruby 1.8.7

    rvm install 1.8.7

### step 4: clone the vcap and vmc repos:

  Optionally create new ssh keys and add them to your github account:
  
    ssh-keygen -t rsa -C me@example.com

Note, this release uses a handful of submodules. It's important to
understand the impact of this which is that after cloning the vcap
repo, you must run: `git submodule update --init`
  
This ends up mounting the services and tests repos in the directory tree of vcap.
Any time you git pull in vcap, you must also git submodule update

    mkdir ~/cloudfoundry; cd ~/cloudfoundry
    git clone https://github.com/cloudfoundry/vcap.git
    
Note, there should be a .rvmrc file in the ~/cloudfoundry/vcap directory.
Make sure that the vcap/.rvmrc is present and that it contains rvm use 1.9.2

    cd ~/cloudfoundry/vcap
    git submodule update --init
    gem install vmc --no-rdoc --no-ri
    
### step 5: run vcap_setup to prep cloudfoundry for launch

Points to keep in mind:

1). Answer Y to all questions

2). Remember your mysql password, you will need it in a minute

    cd ~/cloudfoundry/vcap
    sudo setup/vcap_setup
    
After vcap_setup completes, edit your mysql_node config file 
with the correct password created during install

    cd ~/cloudfoundry/vcap/services/mysql/config 
    vi mysql_node.yml and change mysql.pass to your password
    
### step 6: restart nginx with a custom config

    cd ~/cloudfoundry/vcap
    sudo cp setup/simple.nginx.conf /etc/nginx/nginx.conf
    sudo /etc/init.d/nginx restart
    
### step 7: install bundler gem and run bundler:install

    cd ~/cloudfoundry/vcap    
    gem install bundler --no-rdoc --no-ri
    rake bundler:install

### step 8: start the system  

    cd ~/cloudfoundry/vcap
    bin/vcap start
    bin/vcap tail  # see aggregate logs

### step 9: *Optional, mac users only*, create a local ssh tunnel 

From your vm, run ifconfig and note eth0, let's say it's: 192.168.252.130
go to your mac terminal window and create a local port 80 tunnel.
Once you do this, from both your mac, and from within the vm, api.vcap.me and *.vcap.me 
map to localhost which maps to your running cloudfoundry instance

    sudo ssh -L 80:192.168.252.130:80 mhl@192.168.252.130 -N

Trying your setup
-----------------

### step 10: validate that you can connect and tests pass
#### From the console of your vm, or from your mac (thanks to local tunnel)

    vmc target api.vcap.me
    vmc info

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

### step 11: you are done, make sure you can run a simple hello world app.

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
