# HealthManager 2.0

Health Manager 2.0 (HM2) is a complete re-write of the original Health
Manager.

HM2 monitors the state of the applications and ensures that started
applications are indeed running, their versions and number of
instances correct.

Conceptually, this is done by maintaining a Known State of
applications and comparing it against the Expected State. When
discrepancies are found, actions are initiated to bring the
applications to the Expected State, e.g., start/stop commands are
issued for missing/extra instances, respectively.

## Components

HM2 comprises the following components:

- Manager
- Harmonizer
- Scheduler
- ExpectedStateProvider
- KnownStateProvider
- Nudger

### Manager

Provides an entry point, configures, initializes and registers other
components.

### Harmonizer

Expresses the policy of bringing the applications to the Expected
State by observing the Known State.

Harmonizer sets up the interactions between other components, and aims
to achieve clarity of the intent through delegation:

Known State and Expected State are compared periodically with the use
of the Scheduler and Nudger actions are Scheduled to bring the States
into harmony.

### Scheduler

Encapsulates EventMachine-related functionality such as timer setup
and cancellation, quantization of long-running tasks to prevent EM
Reactor loop blocking.

### Expected State Provider

Provides the expected state of the application, e.g., whether the
application was Started or Stopped, how many instances should be
running, etc. This information comes from the Cloud Controller by way
of http-based Bulk API, hence the concrete class is
BulkBasedExpectedStateProvider

### Known State Provider

The Known state will be discovered from NatsBasedKnownStateProvider,
that will listen to heartbeat and other messages on the NATS bus.

The State of each application is represented by an instant of object
AppState. That object receives updates of the application state,
stores them and notifies registered listeners about events, such as
`instances_missing`, etc


## Harmonization Policy in Detail

### Heartbeat processing

DEAs peridically send out heartbeat messages on NATS bus. These
heartbeats now contain DEA identifying information, as well as information
on application instances running on respective DEAs.

The heartbeats are used to establish "missing" and "extra"
indices. Missing indices are then commanded to start, extra indices
are commanded to stop.

AppState object tracks heartbeats for each instance of each version.

An instance is "missing" if a live version of this instance has not
received a heartbeat in the last `AppState.heartbeat_deadline` seconds.

However, an instance_missing event is only triggered if the AppState
was not reset recently, and if `check_for_missing_instances` method
has been invoked.


### droplet.exited signal

there are three distinct scenarios possible when `droplet.exited`
signal arrives;

- application is stopped; means the application was stopped explicitly, no action required.
- DEA evacuation; the DEA is being evacuated and all instances it runs
  need to be restarted somewhere else. HM2 initiates that restarting
- application crashed; application needs to be restarted unless it
  crashed multiple times in short period of time, in which case it is
  declared `flapping` and is not restarted. This scenario is the most
  complex one and its details have not yet been finalized
