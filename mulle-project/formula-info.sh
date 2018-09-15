# -- Formula Info --
# If you don't have this file, there will be no homebrew
# formula operations.
#
PROJECT="mulle-make"      # your project/repository name
DESC="💄 Build projects with tools like cmake, meson, autoconf"
LANGUAGE="bash"                # c,cpp, objc, bash ...
# NAME="${PROJECT}"        # formula filename without .rb extension

DEPENDENCIES='${MULLE_NAT_TAP}mulle-bashfunctions'

DEBIAN_DEPENDENCIES="mulle-bashfunctions (>= 1.8.0)"
DEBIAN_RECOMMENDATIONS="build-essential"
