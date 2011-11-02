module HealthManager2
  #this class provides answers about droplet's State
  class AppState
  end

  #base class for providing states of applications.  Concrete
  #implementations will use different data sources to obtain and/or
  #persists the state of apps.  This class serves as data holder and
  #interface provider for its users (i.e. HealthManager).
  class AppStateProvider
    attr :state
    def rewind; end
  end

  class ExpectedStateProvider < AppStateProvider
  end

  class KnownStateProvider < AppStateProvider
  end

end
