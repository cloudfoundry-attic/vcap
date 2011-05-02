# Erlang/OTP Support

Erlang/OTP applications are supported when using the rebar build tool and appropriate configuration to generate releases.

## Demonstration

Due to the somewhat irregular nature of Erlang application layouts, support currently only exists for applications
using Rebar, and packaged into Erlang releases (usually via the rebar generate command).

To demonstrate Erlang deployment, we'll deploy the Sean Cribb's riak\_id application (https://github.com/seancribbs/riak_id).

- On your development system, ensure that you have Erlang R14B02 installed.
- In an appropriate directory:
	- <code>git clone https://github.com/seancribbs/riak\_id</code>
	- <code>cd riak\_id</code>
	- <code>wget --no-check-certificate https://github.com/downloads/basho/rebar/rebar</code>
	- <code>echo -riak\_core http \'[{\"0.0.0.0\", '$VMC\_APP\_PORT'}]\' >rel/files/vmc.args</code>
	- Add <code>{copy, "files/vmc.args", "etc/vmc.args"},</code> to rel/reltool.config directly before <code>{template, "files/app.config", "etc/app.config"}</code>
	- <code>make rel</code>
	- <code>cd rel/riak\_id</code>
	- <code>vmc push riak\_id --url riak\_id.vcap.me -n</code>

Visit http://riak_id.vcap.me/id. You should see a generated number. Multiple successive refreshes should generate new numbers.
See the project page for an explanation of the meaning of these.

Notable things in this deployment:

- The application code was untouched
- A file vmc.args was added to the release template. This file details the additional vm arguments that will be provided as the application is launched, thereby allowing for customisation of items such as the http port.
- Multiple instances are not supported on the same machine, as the underlying riak\_core also requires a unique handoff port, which we're unable to allocate.
- An application containing custom nifs won't deploy correctly unless the development machine is of an equivalent architecture to the deployment host (eg linux x64).