SCRIPTS=./bin/installer \
src/mulle-make-bash-completion.sh \
src/mulle-make-build.sh \
src/mulle-make-command.sh \
src/mulle-make-common.sh \
src/mulle-make-compiler.sh \
src/mulle-make-definition.sh \
src/mulle-make-list.sh \
src/mulle-platform-mingw.sh \
src/mulle-make-plugin.sh \
src/plugins/autoconf.sh \
src/plugins/cmake.sh \
src/plugins/configure.sh \
src/plugins/meson.sh \
src/plugins/xcodebuild.sh

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

all:	$(CHECKSTAMPS) mulle-make.chk shellcheck_check jq_check

mulle-make.chk:	mulle-make
	- shellcheck $(SHELLFLAGS) $<
	(shellcheck -f json $(SHELLFLAGS) $< | jq '.[].level' | grep -w error > /dev/null ) && exit 1 || touch $@

installer:
	@ ./bin/installer

clean:
	@- rm src/*.chk
	@- rm src/mulle-make-build-plugins/*.chk

shellcheck_check:
	which shellcheck || brew install shellcheck

jq_check:
	which shellcheck || brew install shellcheck
