# Stager

The stager is responsible for taking an archived form of a user's application
and transforming it into a state capable of being run on a DEA. In CF parlance,
this transformation is called ``staging."

## Sandboxing

Currently, there are two forms of sandboxing available: unix-permissions and
Warden containers. Under the unix-permissions model a unique, unprivileged user
is allocated to each staging operation. The staging code runs as the
unprivileged user. Under the Warden model, a new container is created for each
staging operation. Please see the Warden documentation for a more detailed
description of how isolation works.

We will be removing support for user-based isolation relatively soon.
Consequently, the rest of the document deals only with Warden-based containers.

## Container configuration

Containers are initialized via a set of configuration parameters to the
stager. A sample configuration will help illustrate the available options:

    plugin_runner:
      type: warden
      config:
        socket_path: /tmp/warden.sock

        bind_mounts:
        - /tmp/foo

        environment_path: /tmp/environment

        plugins:
          framework_a: /tmp/framework_a

        runtimes:
          ruby19: /tmp/ruby19

* ```socket_path``` is a path to a unix domain socket the stager should use
  when creating and modifying containers.
* ```bind_mounts``` is an optional list of paths that should be bind-mounted
  inside each container.
* ```environment_path``` is an optional path to a script that will be sourced
  prior to running any staging plugins.
* ```plugins``` is a hash mapping framework names to paths of their respective
  staging plugins. These plugins must adhere to the contract described in the
  next section.
* ```runtimes``` is a hash mapping runtime names to their respective paths.
  These will be bind-mounted inside the container.

## Staging plugins

The staging process is largely opaque to the Stager. In order to be
successfully executed by the stager, a staging plugin for a given framework
needs only to provide an executable file at ```<plugin_root>/bin/stage```. This
script will be called with the following arguments (in order):
```app_source_path```, ```droplet_destination_path```, and
```app_properties_path```.

* ```app_source_path``` is a path to a directory housing the unstaged
  application.
* ```droplet_destination_path``` is a path to a directory where the resulting
  droplet should be placed.
* ```app_properties_path``` is a path to a json-encoded file containing
  application specific details such as service binding information and resource
  limits.
