# See README.md for details; or just run make
DEBCTL := $(wildcard cfbuild*.ctl)
PUBCTL := cfbuild-native.ctl cfbuild-dev.ctl

VERSION := 0.0
RELEASE := testing
URGENT  := low

# SINCE: previous release tag
SINCE  :=

# LOGCHANGES: command to generate Debian-style changelog (of this
# directory only):
AUTHOR := $(shell git config --get user.name)
EMAIL  := $(shell git config --get user.email)
LOGCHANGES := git log --pretty='  * %s' $(SINCE:%=%..) -- . ; \
	date +' -- $(AUTHOR) <$(EMAIL)>  %a, %d %b %Y %T %z'
# TODO: The git-buildpackage package provides git-dch; work out how
# (if installed) to exploit it (or perhaps its internals) to do a
# better job.

DEBS := $(DEBCTL:%.ctl=%_$(VERSION)_all.deb)
pub: $(PUBCTL:%.ctl=%_$(VERSION)_all.deb)
all: $(DEBS)
$(DEBS): cfbuild%_$(VERSION)_all.deb: cfbuild%.ctl ChangeLog%.txt
	@ equivs-build $(@:%_$(VERSION)_all.deb=%.ctl) && lintian $@

Details := ($(VERSION)) $(RELEASE); urgency=$(URGENT)
$(DEBCTL:cfbuild%.ctl=ChangeLog%.txt): FORCE
	@(echo '$(@:ChangeLog%.txt=cfbuild%) $(Details)'; \
	$(LOGCHANGES)) >$@

clean:
	@$(RM) -f ChangeLog*.txt cfbuild*.deb

FORCE: # no command - depending on this forces creation of files.
.PHONY: FORCE clean
