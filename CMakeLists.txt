cmake_minimum_required( VERSION 3.13...99.99)

project( mulle-make VERSION 2.4.2 LANGUAGES NONE)

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
                 WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}"
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


file( GLOB LIBRARY_SCRIPTS
   "src/*.sh"
)

file( GLOB PLUGIN_SCRIPTS
   "src/plugins/*.sh"
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

INSTALL( FILES ${PLUGIN_SCRIPTS}
PERMISSIONS OWNER_EXECUTE OWNER_WRITE OWNER_READ
            GROUP_EXECUTE GROUP_READ
            WORLD_EXECUTE WORLD_READ
DESTINATION "libexec/mulle-make/plugins")


######
#
# must be after CPACK_PACKAGE_VERSION
include( CMakePackage.cmake)
include( CPack)
