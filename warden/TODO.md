# TODO

## Near future

* Use a pool of pre-created containers to avoid start-up latency. This pool can
  have a maximum size, and be lazily re-populated when containers are acquired
  from it.

* Allocate a throw-away user for every container, and synchronize its UID on
  the host with its UID inside the container. This allows code on the host to
  modify files inside the container directly, instead of having to go through
  some kind of proxy.

## Far future

* Implement a shim for the `warden` interface that only uses a chroot jail
  under the hood, so other platforms can run the same code without using actual
  containers.
