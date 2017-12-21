cmake_minimum_required (VERSION 3.0)

project( mulle-make NONE)

#
# Primarily used for packaging on Linux
#
# Debian:
#
# ```
# mkdir package
# cd package
# cmake ..
# cpack -G DEB
# ```
#

execute_process( COMMAND ./mulle-make version
                 WORKING_DIRECTORY "${PROJECT_SOURCE_DIR}"
                 OUTPUT_VARIABLE MULLE_MAKE_VERSION
                 OUTPUT_STRIP_TRAILING_WHITESPACE)
message( STATUS "MULLE_MAKE_VERSION is ${MULLE_MAKE_VERSION} according to mulle-make")


set( PROJECT_VERSION "${MULLE_MAKE_VERSION}")


set( SCRIPTS
mulle-make
)


if(MINGW)
   set( SCRIPTS
${SCRIPTS}
mulle-mingw-cmake
mulle-mingw-make
mulle-mingw-cpp
mulle-mingw-dumpdef.sh
)

#
# Todo need to preprocess this to replace paths
#
   set( BATS
mulle-mingw-dumpdef.bat
)

endif()


set( LIBRARY_SCRIPTS
src/mulle-make-build.sh
src/mulle-make-command.sh
src/mulle-make-dispense.sh
src/mulle-make-compiler.sh
src/mulle-make-log.sh
src/mulle-make-mingw.sh
src/mulle-make-systeminstall.sh
)


set( BUILD_PLUGIN_SCRIPTS
src/plugins/cmake.sh
src/plugins/configure.sh
src/plugins/script.sh
src/plugins/xcodebuild.sh
)


INSTALL( FILES ${SCRIPTS}
PERMISSIONS OWNER_EXECUTE OWNER_WRITE OWNER_READ
            GROUP_EXECUTE GROUP_READ
            WORLD_EXECUTE WORLD_READ
DESTINATION "bin")


INSTALL( FILES ${BATS}
PERMISSIONS OWNER_EXECUTE OWNER_WRITE OWNER_READ
            GROUP_EXECUTE GROUP_READ
            WORLD_EXECUTE WORLD_READ
DESTINATION "bin")

#
# future: install into libexec/mulle-make/${MULLE_MAKE_VERSION}
#         allows multiple versions to co-exist (does it really ?)
#
INSTALL( FILES ${LIBRARY_SCRIPTS}
PERMISSIONS OWNER_EXECUTE OWNER_WRITE OWNER_READ
            GROUP_EXECUTE GROUP_READ
            WORLD_EXECUTE WORLD_READ
DESTINATION "libexec/mulle-make")

INSTALL( FILES ${BUILD_PLUGIN_SCRIPTS}
PERMISSIONS OWNER_EXECUTE OWNER_WRITE OWNER_READ
            GROUP_EXECUTE GROUP_READ
            WORLD_EXECUTE WORLD_READ
DESTINATION "libexec/mulle-make/plugins")


######
#
# must be after CPACK_PACKAGE_VERSION
include( CMakePackage.txt)
include( CPack)

