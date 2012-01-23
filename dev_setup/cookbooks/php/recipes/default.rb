#
# Cookbook Name:: php
# Recipe:: default
#
# Copyright 2011, VMware
# Copyright 2011, AppFog
#

case node['platform']
when "ubuntu"
  %w[
    libpcre3
    libpcre3-dev
    apache2
    libapr1
    libaprutil1
    php5
    php5-dev
    php5-mysql
    php5-pgsql
    php5-gd
    php5-common
    php5-curl
    php5-mcrypt
    php5-imagick
    php5-xmlrpc
    php5-imap
    php-pear
    zend-framework
  ].each {|pkg| package pkg }


  bash "Setup php" do
    code <<-EOH
      /etc/init.d/apache2 stop
      update-rc.d -f apache2 remove

      cd /tmp/
      pear channel-discover pear.phpunit.de
      pear channel-discover pear.symfony-project.com
      pear channel-discover components.ez.no
      pear install phpunit/PHPUnit

      yes | pecl install apc
      yes | pecl install memcache
      yes | pecl install mongo

      git clone git://github.com/owlient/phpredis.git
      cd phpredis
      phpize && ./configure && make && sudo make install
      cd ..
      rm -rf phpredis

      php -v
    EOH
    not_if do
      ::File.exists?("/usr/bin/php")
    end

  end


  template File.join("", "etc", "php5", "apache2", "conf.d", "cf.ini") do
    source "apache2.cnf.erb"
    owner "root"
    group "root"
    mode "0600"
  end

end
