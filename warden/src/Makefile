default: all

# Proxy any target to the Makefiles in the per-tool directories
%:
	cd clone && $(MAKE) $@
	cd oom && $(MAKE) $@

.PHONY: default
