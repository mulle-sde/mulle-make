SCRIPTS=install.sh \
src/mulle-bootstrap-array.sh \
src/mulle-bootstrap-auto-update.sh \
src/mulle-bootstrap-brew.sh \
src/mulle-bootstrap-build.sh \
src/mulle-bootstrap-clean.sh \
src/mulle-bootstrap-command.sh \
src/mulle-bootstrap-common-settings.sh \
src/mulle-bootstrap-copy.sh \
src/mulle-bootstrap-core-options.sh \
src/mulle-bootstrap-defer.sh \
src/mulle-bootstrap-dependency-resolve.sh \
src/mulle-bootstrap-dispense.sh \
src/mulle-bootstrap-fetch.sh \
src/mulle-bootstrap-functions.sh \
src/mulle-bootstrap-gcc.sh \
src/mulle-bootstrap-git.sh \
src/mulle-bootstrap-init.sh \
src/mulle-bootstrap-local-environment.sh \
src/mulle-bootstrap-logging.sh \
src/mulle-bootstrap-mingw.sh \
src/mulle-bootstrap-mv-force.sh \
src/mulle-bootstrap-paths.sh \
src/mulle-bootstrap-project.sh \
src/mulle-bootstrap-repositories.sh \
src/mulle-bootstrap-source.sh \
src/mulle-bootstrap-scripts.sh \
src/mulle-bootstrap-settings.sh \
src/mulle-bootstrap-show.sh \
src/mulle-bootstrap-snip.sh \
src/mulle-bootstrap-status.sh \
src/mulle-bootstrap-systeminstall.sh \
src/mulle-bootstrap-tag.sh \
src/mulle-bootstrap-warn-scripts.sh \
src/mulle-bootstrap-xcode.sh \
src/mulle-bootstrap-zombify.sh \
src/mulle-bootstrap-build-plugins/autoconf.sh \
src/mulle-bootstrap-build-plugins/cmake.sh \
src/mulle-bootstrap-build-plugins/configure.sh \
src/mulle-bootstrap-build-plugins/script.sh \
src/mulle-bootstrap-build-plugins/xcodebuild.sh \
src/mulle-bootstrap-source-plugins/git.sh \
src/mulle-bootstrap-source-plugins/svn.sh \
src/mulle-bootstrap-source-plugins/symlink.sh \
src/mulle-bootstrap-source-plugins/tar.sh \
src/mulle-bootstrap-source-plugins/zip.sh

CHECKSTAMPS=$(SCRIPTS:.sh=.chk)

#
# catch some more glaring problems, the rest is done with sublime
#
SHELLFLAGS=-x -e SC2016,SC2034,SC2086,SC2164,SC2166,SC2006,SC1091,SC2039,SC2181,SC2059,SC2196,SC2197 -s sh

.PHONY: all
.PHONY: clean
.PHONY: shellcheck_check

%.chk:	%.sh
	- shellcheck $(SHELLFLAGS) $<
	(shellcheck -f json $(SHELLFLAGS) $< | jq '.[].level' | grep -w error > /dev/null ) && exit 1 || touch $@

all:	$(CHECKSTAMPS) mulle-bootstrap.chk shellcheck_check jq_check

mulle-bootstrap.chk:	mulle-bootstrap
	- shellcheck $(SHELLFLAGS) $<
	(shellcheck -f json $(SHELLFLAGS) $< | jq '.[].level' | grep -w error > /dev/null ) && exit 1 || touch $@

install:
	@ ./install.sh

clean:
	@- rm src/*.chk
	@- rm src/mulle-bootstrap-build-plugins/*.chk
	@- rm src/mulle-bootstrap-source-plugins/*.chk

shellcheck_check:
	which shellcheck || brew install shellcheck

jq_check:
	which shellcheck || brew install shellcheck
