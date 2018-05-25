# -- Formula Info --
# If you don't have this file, there will be no homebrew
# formula operations.
#
PROJECT="mulle-make"      # your project/repository name
DESC="💄 Build projects with tools like cmake, meson, autoconf"
LANGUAGE="bash"                # c,cpp, objc, bash ...
# NAME="${PROJECT}"        # formula filename without .rb extension

DEPENDENCIES='${BOOTSTRAP_TAP}mulle-bashfunctions'

DEBIAN_DEPENDENCIES="mulle-bashfunctions (>= 1.5.0), build-essential"
