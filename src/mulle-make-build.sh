# shellcheck shell=bash
#
#   Copyright (c) 2015 Nat! - Mulle kybernetiK
#   All rights reserved.
#
#   Redistribution and use in source and binary forms, with or without
#   modification, are permitted provided that the following conditions are met:
#
#   Redistributions of source code must retain the above copyright notice, this
#   list of conditions and the following disclaimer.
#   Redistributions in binary form must reproduce the above copyright notice,
#   this list of conditions and the following disclaimer in the documentation
#   and/or other materials provided with the distribution.
#
#   Neither the name of Mulle kybernetiK nor the names of its contributors
#   may be used to endorse or promote products derived from this software
#   without specific prior written permission.
#
#   THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
#   AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
#   IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
#   ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
#   LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
#   CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
#   SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
#   INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
#   CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
#   ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
#   POSSIBILITY OF SUCH DAMAGE.
#
MULLE_MAKE_BUILD_SH='included'


make::build::emit_common_options()
{
   local marks="$1"

   if [ "${marks}" = "common-prefix" ]
   then
      cat <<EOF
   --prefix <prefix>          : prefix to use for build products e.g. /usr/local
EOF
   fi

      cat <<EOF
   -D<key>=<value>            : set the definition named key to value
   -D<key>+=<value>           : append a += definition for the buildtool
   --build-dir <dir>          : specify build directory
   --debug                    : build with configuration "Debug"
   --include-path <path>      : specify header search PATH, separated by :
   --definition-dir <path>    : specify definition directories (multi-use)
   --dynamic                  : prefer dynamic library output
   --library-path <path>      : specify library search PATH, separated by :
   --no-ninja                 : prefer make over ninja
   --release                  : build with configuration "Release" (Default)
   --mulle-test               : build for mulle-test
   --verbose-make             : verbose make output
EOF
   case "${MULLE_UNAME}" in
      mingw)
      ;;

      darwin)
         cat <<EOF
   --frameworks-path <path>   : specify Frameworks search PATH, separated by :
   -j <cores>                 : number of cores parameter for make (${MULLE_CORES})
EOF
      ;;

      *)
         cat <<EOF
   -j <cores>                 : number of cores parameter for make (${MULLE_CORES})
EOF
      ;;
   esac
}


make::build::emit_uncommon_options()
{
   local marks="$1"

   if [ "${marks}" != "common-prefix" ]
   then
      cat <<EOF
   --prefix <prefix>          : prefix to use for build products e.g. /usr/local
EOF
   fi

   cat <<EOF
   --append <key>[+]=<value>  : like -D, but appends value to a previous value
   --configuration <name>     : configuration to build like Debug or Release
   --clean                    : always clean before building
   --ifempty <key>[+]=<value> : like -D, but only if no previous value exists
   --library-style <type>     : library format dynamic,standalone,(static)
   --log-dir <dir>            : specify log directory
   --no-determine-sdk         : don't try to figure out the default SDK
   --phase <name>             : run make phase (for parallel builds)
   --platform <name>          : platform to build for (Default)
   --project-name <name>      : explicitly set project name
   --project-language <c|cpp> : set project language
   --remove<key>[+]=<value>   : like -D,but removes value from a previous value
   --set-is-plus              : all definitions are force to be +=
   --sdk <name>               : SDK to use (Default)
   --tool-preferences <list>  : tool preference order. Tools are separated by ','
   -U<key>                    : undefine a definition or += definition
EOF
   case "${MULLE_UNAME}" in
      darwin)
         echo "\
   --xcode-config-file <file> : specify xcode config file to use"
      ;;
   esac
}


make::build::emit_options()
{
   local marks="$1"

   if [ "${MULLE_FLAG_LOG_VERBOSE}" = 'YES' ]
   then
      make::build::emit_uncommon_options "${marks}"
   fi
   make::build::emit_common_options "${marks}"
}


make::build::project_usage()
{
   cat <<EOF >&2
Usage:
   ${MULLE_USAGE_NAME} project [options] [directory]

   Build the project in directory. If directory is omitted, the current
   directory is used.

   Build settings can be specified by the command line or can be read from a
   definition directory. Definitions read from the file system undergo variable
   expansion. You generally do not interact with ${MULLE_USAGE_NAME} through
   environment variables (though there are four notable exceptions) but 
   through these definition directories.

   You can specify a preference for building dynamic or static libraries,
   but it may only work with some cmake and autoconf projects.

Options:
EOF
   make::build::emit_options "common-prefix" | LC_ALL=C sort

   cat <<EOF >&2

Environment:
   CFLAGS
   CFLAGS
   CXXFLAGS
   LDFLAGS

EOF
   exit 1
}


make::build::clean_usage()
{
   cat <<EOF >&2
Usage:
   ${MULLE_USAGE_NAME} clean [options]

   Clean the build directory. If you want to clean just the log files
   use ${MULLE_USAGE_NAME} clean log.

Example:
   ${MULLE_USAGE_NAME} clean

Options:
EOF
   make::build::emit_options "common-prefix" | LC_ALL=C sort

   exit 1
}


make::build::install_usage()
{
   cat <<EOF >&2
Usage:
   ${MULLE_USAGE_NAME} install [options] [src] [dst]

   Build the project in the directory src. Then the build results are
   installed in dst.  If dst is omitted '/tmp' is used. If --prefix is 
   specified in options then do not specify dst as well.

Example:
   ${MULLE_USAGE_NAME} install "${HOME}/src/mulle-buffer" /tmp/usr

Options:
EOF
   make::build::emit_options "common-prefix" | LC_ALL=C sort

   exit 1
}


make::build::list_usage()
{
   cat <<EOF >&2
Usage:
   ${MULLE_USAGE_NAME} list [options]

   Do not build anything but list definitions as defined. With this command
   you can investigate how various set flags like '--clobber' affect the
   composition of the final value.

Example:
      ${MULLE_USAGE_NAME} definition --definition-dir a set FOO a
      ${MULLE_USAGE_NAME} definition --definition-dir b set --append0 FOO b
      ${MULLE_USAGE_NAME} list --definition-dir a --definition-dir b

Options:
EOF
   make::build::emit_options "common-prefix" | LC_ALL=C sort

   exit 1
}


make::build::make_directories()
{
   log_entry "make::build::make_directories" "$@"

   local kitchendir="$1"
   local logsdir="$2"

   [ -z "${kitchendir}" ] && _internal_fail "kitchendir is empty"

   if [ -d "${kitchendir}" -a "${DEFINITION_CLEAN_BEFORE_BUILD}" = 'YES' ]
   then
      log_fluff "Cleaning build directory \"${kitchendir}\""
      rmdir_safer "${kitchendir}"
   else
      mkdir_if_missing "${kitchendir}"
   fi

   mkdir_if_missing "${logsdir}"
}


#
# 0 OK
# 127 preference does not support it
# 1 or other preference build failed
#
# need to run in subshell so that plugin changes
# to variables are ignored
#
make::build::__build_with_preference_if_possible()
{
   log_entry "make::build::__build_with_preference_if_possible" "$@"

   [ ! -z "${configuration}" ]  || _internal_fail "configuration not defined"
   [ ! -z "${name}" ]           || _internal_fail "name not defined"
   [ ! -z "${sdk}" ]            || _internal_fail "sdk not defined"
   [ ! -z "${platform}" ]       || _internal_fail "platform not defined"
   [ ! -z "${preference}" ]     || _internal_fail "preference not defined"
   [ ! -z "${cmd}" ]            || _internal_fail "cmd not defined"
   [ ! -z "${srcdir}" ]         || _internal_fail "srcdir not defined"
# dstdir can be empty (check what DEFINITION_PREFIX does differently)
#   [ ! -z "${dstdir}" ]        || _internal_fail "dstdir not defined"
   [ ! -z "${kitchendir}" ]     || _internal_fail "kitchendir not defined"
   [ ! -z "${logsdir}" ]        || _internal_fail "logsdir not defined"

   (
      local TOOLNAME="${preference}"

      local projectinfo

      if ! "make::plugin::${preference}::r_test" "${srcdir}" \
                                                 "${DEFINITION_BUILD_SCRIPT}" \
                                                 "${definitiondirs}"
      then
         return 127
      fi
      projectinfo="${RVAL}"

      [ -z "${projectinfo}" ] && \
         _internal_fail "make::plugin::${preference}::r_test did not return projectinfo"
      #statements

      local blurb
      local conftext
      local prettykitchendir
      local escaped

      prettykitchendir="${kitchendir#"${MULLE_USER_PWD}/"}"
      if [ "${prettykitchendir#"${HOME}/"}" != "${prettykitchendir}" ]
      then
         prettykitchendir="~/${prettykitchendir#"${HOME}/"}"
      fi

      conftext="${configuration}"

      local style
      local underline

      if [ "${OPTION_UNDERLINE}" = 'YES' ]
      then
         underline="${C_UNDERLINE}"
      fi

      style="${DEFINITION_LIBRARY_STYLE:-${DEFINITION_PREFERRED_LIBRARY_STYLE}}"
      if [ ! -z "${style}" ]
      then
         conftext="${conftext}/${style}"
      fi

      blurb="${underline}Let ${C_RESET_BOLD}${underline}${TOOLNAME}"
      if [ ! -z "${MAKE}" ]
      then
         r_extensionless_basename "${MAKE}"
         blurb="${blurb}${C_INFO}${underline}/${C_RESET_BOLD}${underline}${RVAL}"
      fi

      blurb="${blurb}${C_INFO}${underline} do a \
${C_MAGENTA}${C_BOLD}${underline}${conftext}${C_INFO}${underline} build"
      if [ ! -z "${OPTION_PHASE}" ]
      then
         blurb="${blurb} ${C_MAGENTA}${C_BOLD}${OPTION_PHASE}${C_INFO}${underline} phase"
      fi
      blurb="${blurb}${underline} of \
${C_MAGENTA}${C_BOLD}${underline}${name}${C_INFO}"

      if [ "${sdk}" != "Default" -o "${MULLE_FLAG_LOG_VERBOSE}" = 'YES' ]
      then
         blurb="${blurb}${underline} for SDK \
${C_MAGENTA}${C_BOLD}${underline}${sdk}${C_INFO}"
      fi

      if [ "${MULLE_FLAG_LOG_VERBOSE}" = 'YES' ]
      then
         blurb="${blurb}${underline} in \"${prettykitchendir}\" ..."
      fi
      blurb="${blurb}${underline} ..."


      log_info "${blurb}"

      if ! "make::plugin::${preference}::build" "${cmd}" \
                                                "${projectinfo}" \
                                                "${sdk}" \
                                                "${platform}" \
                                                "${configuration}" \
                                                "${srcdir}" \
                                                "${dstdir}" \
                                                "${kitchendir}" \
                                                "${logsdir}"
      then
         _internal_fail "build_${preference} should exit on failure and not return"
      fi
   )
}

# TODO: doesn't use _variables yet,
#
# local name
# local kitchendir
# local logsdir
#
# needs and sets srcdir
#
make::build::__determine_directories()
{
   log_entry "make::build::__determine_directories" "$@"

   local create_if_missing="$1"

   name="${DEFINITION_PROJECT_NAME}"
   if [ -z "${name}" ]
   then
      r_basename "${srcdir}"
      name="${RVAL}"
   fi

   #
   # remove symlinks
   #
   r_canonicalize_path "${srcdir}"
   srcdir="${RVAL}"

   # sometimes there is already a "build" dir there, which we don't want
   # to destroy, so if there is a build but no build/.mulle-make,
   # mulle-make will use ... a random directory.

   local markerfile

   # we create a marker file, if we are running default (no DEFINITION_BUILD_DIR given)
   kitchendir="${DEFINITION_BUILD_DIR}"

   if [ -z "${kitchendir}" ]
   then
      markerfile="${MULLE_MAKE_ETC_DIR}/build-dir"

      # always prefer "build", if available
      if [ ! -d "${srcdir}/build" ]
      then
         kitchendir="${srcdir}/build"
      else
         kitchendir="`grep -E -v '^#' "${markerfile}" 2> /dev/null`"

         if [ -z "${kitchendir}" ]
         then
            if [ "${create_if_missing}" = 'NO' ]
            then
               return 1
            fi

            local uuid
            local len=4 # turbo pedantic

            while :
            do
               r_uuidgen
               uuid="${RVAL}"
               kitchendir="${srcdir}/build-${uuid:0:${len}}"
               if [ ! -d "${kitchendir}" ]
               then
                  log_info "Use build directory ${C_RESET_BOLD}${kitchendir#"${MULLE_USER_PWD}/"}"
                  break
               fi
               len=$(( len + 1 ))
            done
         fi
      fi
   fi

   logsdir="${DEFINITION_LOG_DIR:-${kitchendir}/.log}"

   if [ "${create_if_missing}" = 'NO' ]
   then
      if [ ! -d "${logsdir}" ]
      then
         return 1
      fi
   else
      make::build::make_directories "${kitchendir}" "${logsdir}"

      #
      # only memorize if kitchendir is not the default
      #
      if [ ! -z "${markerfile}" ]
      then
         r_mkdir_parent_if_missing "${markerfile}"
         redirect_exekutor "${markerfile}" \
            echo "# mulle-make memorizes the name of the \
build directory:
${kitchendir}" || exit 1
      else
         log_debug "Not remembering build dir"
      fi
   fi

   # now known to exist, so we can canonicalize
   # canonicalize can fail on dry-run
   if r_canonicalize_path "${kitchendir}"
   then
      kitchendir="${RVAL}"
   fi
   if r_canonicalize_path "${logsdir}"
   then
      logsdir="${RVAL}"
   fi
}


make::build::build_with_sdk_platform_configuration_preferences()
{
   log_entry "make::build::build_with_sdk_platform_configuration_preferences" "$@"

   local cmd="$1"; shift

   local srcdir="$1"
   local dstdir="$2"
   local sdk="$3"
   local platform="$4"
   local configuration="$5"
   local preferences="$6"
   local definitiondirs="$7"

   [ -z "${srcdir}" ]        && _internal_fail "srcdir is empty"
   [ -z "${configuration}" ] && _internal_fail "configuration is empty"
   [ -z "${sdk}" ]           && _internal_fail "sdk is empty"
   [ -z "${platform}" ]      && _internal_fail "platform is empty"
   [ -z "${preferences}" ]   && _internal_fail "preferences is empty"

   if [ "${configuration}" = "lib" -o "${configuration}" = "include" -o "${configuration}" = "Frameworks" ]
   then
      fail "You are just asking for major trouble naming your configuration \"${configuration}\"."
   fi

   local name
   local kitchendir
   local logsdir

   make::build::__determine_directories

   log_setting "kitchendir : ${kitchendir}"
   log_setting "logsdir    : ${logsdir}"

   local rval
   local preference

   .for preference in ${preferences}
   .do
      # pass local context w/o arguments
      make::build::__build_with_preference_if_possible
      rval=$?
      if [ $rval -ne 127 ]
      then
         return $rval
      fi
   .done

   return 127
}


#
# used by plugins for environment calling cmake and friends.
#
make::build::r_env_flags()
{
   log_entry "make::build::r_env_flags" "$@"

   RVAL="MULLE_MAKE_VERSION='${MULLE_EXECUTABLE_VERSION}'"
}


make::build::clean()
{
   log_entry "make::build::clean" "$@"

   local srcdir="$1"

   local kitchendir
   local name
   local logsdir

   make::build::__determine_directories

   rmdir_safer "${kitchendir}"
}


make::build::build()
{
   log_entry "make::build::build" "$@"

   local cmd="$1"
   local srcdir="$2"
   local dstdir="$3"
   local definitiondirs="$4"
   local set_is_plus="${5:-}"

   #
   # need these three defined before read_info_dir
   #
   r_simplified_absolutepath "${srcdir}"
   MULLE_MAKE_PROJECT_DIR="${RVAL}"
   r_simplified_absolutepath "${dstdir}"
   MULLE_MAKE_DESTINATION_DIR="${RVAL}"


   #
   # this is typically a definition in .mulle/etc|share/craft
   #
   local definitiondir

   .foreachline definitiondir in ${definitiondirs}
   .do
      make::definition::read "${definitiondir}" "${set_is_plus}"
   .done

   local sdk

   sdk="${DEFINITION_SDK:-Default}"
   case "${sdk}" in
      Default)
      ;;

      maosx)
         case "${MULLE_UNAME}" in
            darwin)
               sdk="Default"
            ;;
         esac
      ;;

      Debug|Release|Test)
         log_warning "SDK named like a standard configuration"
      ;;

      "")
         fail "An Empty sdk is not possible (use \"Default\")"
      ;;
   esac

   local platform

   platform="${DEFINITION_PLATFORM}"
   case "${platform:-Default}" in
      "Default")
         platform="${MULLE_UNAME}"
      ;;

      Debug|Release|Test)
         log_warning "Platform named like a standard configuration"
      ;;
   esac

   local configuration

   configuration="${DEFINITION_CONFIGURATION}"
   case "${configuration:-Default}" in
      Default)
         configuration="Release"
      ;;

      "")
         fail "An empty configuration is not possible (use \"Release\")"
      ;;
   esac

   if [ -z "${DEFINITION_PLUGIN_PREFERENCES}" ]
   then
      DEFINITION_PLUGIN_PREFERENCES='cmake:meson:autoconf:configure:make'
      case "${MULLE_UNAME}" in
         darwin)
            if [ "${DEFINITION_PREFER_XCODEBUILD}" = 'YES' ]
            then
               r_colon_concat "xcodebuild" "${DEFINITION_PLUGIN_PREFERENCES}"
               DEFINITION_PLUGIN_PREFERENCES="${RVAL}"
            else
               r_colon_concat "${DEFINITION_PLUGIN_PREFERENCES}" "xcodebuild"
               DEFINITION_PLUGIN_PREFERENCES="${RVAL}"
            fi
         ;;
      esac
   fi

   #
   # If we have a script, can we use it ?
   # If yes, we only use the script and fail for every other plugin
   #
   if [ ! -z "${DEFINITION_BUILD_SCRIPT}" ]
   then
      local ok

      case "${OPTION_ALLOW_SCRIPTS}" in
         ""|'YES'|'NO')
            ok="${OPTION_ALLOW_SCRIPTS}"
         ;;

         *)
            if find_item "${OPTION_ALLOW_SCRIPTS}" "${DEFINITION_BUILD_SCRIPT}" ||
               find_item "${OPTION_ALLOW_SCRIPTS}" "${DEFINITION_BUILD_SCRIPT%.${MULLE_UNAME}}"
            then
               ok='YES'
            else
               ok='NO'
            fi
         ;;
      esac

      if [ "${ok}" != 'YES' ]
      then
         fail "No permission to run script \"${DEFINITION_BUILD_SCRIPT}\".
${C_INFO}Use \"--allow-build-script ${DEFINITION_BUILD_SCRIPT}\" option or enable the
script permanently:
${C_RESET_BOLD}   mulle-sde environment --global set --concat MULLE_CRAFT_USE_SCRIPTS ${DEFINITION_BUILD_SCRIPT}
${C_RESET_BOLD}   mulle-sde craft --build-style ${configuration} --allow-build-script ${DEFINITION_BUILD_SCRIPT}"
      fi

      DEFINITION_PLUGIN_PREFERENCES="script"
      log_verbose "A script is defined, only considering a script build now"
   else
      log_fluff "No script defined"
   fi


   #
   # filter preferences for command line options and "convenient"
   # definitions
   #
   local tmp

   if [ "${DEFINITION_USE_AUTOCONF}" = 'NO' ]
   then
      tmp=":${DEFINITION_PLUGIN_PREFERENCES}"
      DEFINITION_PLUGIN_PREFERENCES="${tmp//:autoconf/}"
   fi
   if [ "${DEFINITION_USE_CMAKE}" = 'NO' ]
   then
      tmp=":${DEFINITION_PLUGIN_PREFERENCES}"
      DEFINITION_PLUGIN_PREFERENCES="${tmp//:cmake/}"
   fi
   if [ "${DEFINITION_USE_CONFIGURE}" = 'NO' ]
   then
      tmp=":${DEFINITION_PLUGIN_PREFERENCES}"
      DEFINITION_PLUGIN_PREFERENCES="${tmp//:configure/}"
   fi
   if [ "${DEFINITION_USE_MAKE}" = 'NO' ]
   then
      tmp=":${DEFINITION_PLUGIN_PREFERENCES}"
      DEFINITION_PLUGIN_PREFERENCES="${tmp//:make/}"
   fi
   if [ "${DEFINITION_USE_MESON}" = 'NO' ]
   then
      tmp=":${DEFINITION_PLUGIN_PREFERENCES}"
      DEFINITION_PLUGIN_PREFERENCES="${tmp//:meson/}"
   fi
   if [ "${DEFINITION_USE_SCRIPT}" = 'NO' ]
   then
      tmp=":${DEFINITION_PLUGIN_PREFERENCES}"
      DEFINITION_PLUGIN_PREFERENCES="${tmp//:script/}"
   fi
   if [ "${DEFINITION_USE_XCODEBUILD}" = 'NO' ]
   then
      tmp=":${DEFINITION_PLUGIN_PREFERENCES}"
      DEFINITION_PLUGIN_PREFERENCES="${tmp//:xcodebuild/}"
   fi

   DEFINITION_PLUGIN_PREFERENCES="${DEFINITION_PLUGIN_PREFERENCES##:}"
   DEFINITION_PLUGIN_PREFERENCES="${DEFINITION_PLUGIN_PREFERENCES%%:}"

   # used to receive values from make::plugin::loads
   local preferences

   make::plugin::r_loads "${DEFINITION_PLUGIN_PREFERENCES}" # can't be subshell !
   preferences="${RVAL}"

   if [ -z "${preferences}" ]
   then
      fail "Don't know how to build \"${srcdir}\".
There are no plugins available for requested tools \"`echo ${DEFINITION_PLUGIN_PREFERENCES}`\""
   fi

   log_debug "Available mulle-make plugins for ${MULLE_UNAME} are: `echo "${preferences}"`"


   make::build::build_with_sdk_platform_configuration_preferences "${cmd}" \
                                                                  "${srcdir}" \
                                                                  "${dstdir}" \
                                                                  "${sdk}" \
                                                                  "${platform}" \
                                                                  "${configuration}" \
                                                                  "${preferences}"  \
                                                                  "${definitiondirs}"
   case "$?" in
      0)
      ;;

      127)
         local pluginstring

         pluginstring="`sort <<< "${preferences}" | tr '\n' ',' `"
         fail "Don't know how to build \"${srcdir}\" with plugins ${pluginstring%%,} in \"${srcdir}\""
      ;;

      *)
         exit 1
      ;;
   esac
}


make::build::list()
{
   log_info "Definitions"

   local definitiondirs="$1"

   local definitiondir

   .foreachline definitiondir in ${definitiondirs}
   .do
      make::definition::read "${definitiondir}"
   .done

   make::definition::r_print "${DEFINED_SET_DEFINITIONS}" \
                             "${DEFINED_PLUS_DEFINITIONS}" \
                             "" \
                             "=" \
                             "+=" \
                             "" \
                             "" \
                             $'\n'
   [ ! -z "${RVAL}" ] && printf "%s\n" "${RVAL}"

   :
}


make::build::common()
{
   log_entry "make::build::common" "$@"

   local cmd="${1:-project}"
   local argument="$2"

   [ -z "${DEFAULT_IFS}" ] && _internal_fail "IFS fail"

   include "parallel"

   # will set MULLE_CORES
   r_get_core_count

   #
   # TODO: DEFINITIONS should not have DEFAULT values 
   #     
   local OPTION_ALLOW_UNKNOWN_OPTION

   #
   # TODO: these definitions should not be local
   #
   #   local DEFINITION_CLEAN_BEFORE_BUILD
   #   local DEFINITION_CONFIGURATION
   #   local DEFINITION_DETERMINE_SDK
   #   local DEFINITION_SDK
   #   local DEFINITION_USE_NINJA
   #   local DEFINITION_PLATFORM
   #   local DEFINITION_LIBRARY_STYLE
   #   local DEFINITION_PREFERRED_LIBRARY_STYLE
   #   local DEFINITION_TARGET
   #
   #   # why are these definitions ?
   #   local DEFINITION_BUILD_DIR
   #   local DEFINITION_LOG_DIR
   #   local DEFINITION_PREFIX

   local OPTION_ALLOW_SCRIPTS
   local OPTION_ANALYZE
   local OPTION_CORES
   local OPTION_INFO_DIRS
   local OPTION_LOAD
   local OPTION_RERUN_CMAKE
   local OPTION_SET_IS_PLUS
   local OPTION_TARGET

   local state
   local value

   state='NEXT'
   if [ ! -z "${argument}" ]
   then
      state='FIRST'
   fi

   include "make::common"
   include "make::definition"

   while :
   do
      case "${state}" in
         FIRST)
            state='NEXT'
         ;;

         NEXT)
            if ! read -r argument
            then
               break
            fi
         ;;
      esac

      case "${argument}" in
         -h*|--help|help)
            "${usage}"
         ;;

         --analyze)
            OPTION_ANALYZE='YES'
         ;;

         --no-analyze)
            OPTION_ANALYZE='NO'
         ;;

         --allow-script)
            OPTION_ALLOW_SCRIPTS='YES'
         ;;

         --allow-build-script)
            read -r value || fail "missing argument to \"${value}\""

            if [ "${OPTION_ALLOW_SCRIPTS}" != 'YES' ]
            then
               if [ "${OPTION_ALLOW_SCRIPTS}" = 'NO' ]
               then
                  OPTION_ALLOW_SCRIPTS="${value}"
               else
                  r_comma_concat "${OPTION_ALLOW_SCRIPTS}" "${value}"
                  OPTION_ALLOW_SCRIPTS="${RVAL}"
               fi
            fi
         ;;

         --no-allow-script)
            OPTION_ALLOW_SCRIPTS='NO'
         ;;

         --allow-unknown-option)
            OPTION_ALLOW_UNKNOWN_OPTION='YES'
         ;;

         --no-allow-unknown-option)
            OPTION_ALLOW_UNKNOWN_OPTION='NO'
         ;;

         --debug)
            DEFINITION_CONFIGURATION='Debug'
         ;;

         --release)
            DEFINITION_CONFIGURATION='Release'
         ;;

         --mulle-test)
            OPTION_MULLE_TEST='YES'
         ;;

         --ninja)
            DEFINITION_USE_NINJA='YES'
         ;;

         --no-ninja)
            DEFINITION_USE_NINJA='NO'
         ;;

         --ccache)
            read -r DEFINITION_C_COMPILER_CACHE || fail "missing argument to \"${argument}\""
            DEFINITION_CXX_COMPILER_CACHE="${DEFINITION_C_COMPILER_CACHE}"
         ;;

         --make)
            DEFINITION_USE_MAKE='YES'

            DEFINITION_USE_AUTOCONF='NO'
            DEFINITION_USE_CONFIGURE='NO'
            DEFINITION_USE_CMAKE='NO'
            DEFINITION_USE_MESON='NO'
            DEFINITION_USE_XCODEBUILD='NO'
         ;;

         --no-make)
            DEFINITION_USE_MAKE='NO'
         ;;

         --autoconf)
            DEFINITION_USE_AUTOCONF='YES'
            # keep CONFIGURE ALIVE THOUGH
            DEFINITION_USE_CMAKE='NO'
            DEFINITION_USE_MAKE='NO'
            DEFINITION_USE_MESON='NO'
            DEFINITION_USE_XCODEBUILD='NO'
         ;;

         --no-autoconf)
            DEFINITION_USE_AUTOCONF='NO'
         ;;

         --configure)
            DEFINITION_USE_AUTOCONF='NO'
            DEFINITION_USE_CONFIGURE='YES'
            DEFINITION_USE_CMAKE='NO'
            DEFINITION_USE_MAKE='NO'
            DEFINITION_USE_MESON='NO'
            DEFINITION_USE_XCODEBUILD='NO'
         ;;

         --no-configure)
            DEFINITION_USE_CONFIGURE='NO'
         ;;

         --no-cmake)
            DEFINITION_USE_CMAKE='NO'
         ;;

         --xcodebuild)
            DEFINITION_USE_XCODEBUILD='YES'
            DEFINITION_USE_AUTOCONF='NO'
            DEFINITION_USE_CONFIGURE='NO'
            DEFINITION_USE_CMAKE='NO'
            DEFINITION_USE_MAKE='NO'
            DEFINITION_USE_MESON='NO'
            DEFINITION_USE_XCODEBUILD='NO'
         ;;

         --no-xcodebuild)
            DEFINITION_USE_XCODEBUILD='NO'
         ;;

         --determine-sdk)
            DEFINITION_DETERMINE_SDK='YES'
         ;;

         --no-determine-sdk)
            DEFINITION_DETERMINE_SDK='NO'
         ;;

         --plugins|--plugin-preferences|--tools|--tool-preferences)
            read -r value || fail "missing argument to \"${argument}\""

            # convenient to allow empty parameter here (for mulle-bootstrap)
            if [ ! -z "${value}" ]
            then
               DEFINITION_PLUGIN_PREFERENCES="${value}"
            fi
         ;;

         --project-name|--name)
            read -r DEFINITION_PROJECT_NAME || fail "missing argument to \"${argument}\""
         ;;

         --project-language|--language)
            read -r DEFINITION_PROJECT_LANGUAGE || fail "missing argument to \"${argument}\""
         ;;

         --project-dialect|--dialect)
            read -r DEFINITION_PROJECT_DIALECT || fail "missing argument to \"${argument}\""
         ;;

         --xcode-config-file)
            read -r DEFINITION_XCODE_XCCONFIG_FILE || fail "missing argument to \"${argument}\""
         ;;

         #
         # with shortcuts
         #
         --build-dir)
            read -r DEFINITION_BUILD_DIR || fail "missing argument to \"${argument}\""
         ;;

         -c|--configuration)
            read -r DEFINITION_CONFIGURATION || fail "missing argument to \"${argument}\""
         ;;

         -d|--definition-dir|--info-dir|--makeinfo-dir|--aux-definition-dir)
            read -r value || fail "missing argument to \"${argument}\""

            r_add_line "${OPTION_INFO_DIRS}" "${value}"
            OPTION_INFO_DIRS="${RVAL}"
         ;;

         --serial|--no-parallel)
            OPTION_CORES="1"
         ;;

         -j|--cores)
            read -r OPTION_CORES || fail "missing argument to \"${argument}\""

            case "${MULLE_UNAME}" in
               mingw)
                   "${usage}"
               ;;
            esac
         ;;

         --clean|-k)
            DEFINITION_CLEAN_BEFORE_BUILD='YES'
         ;;

         --no-clean|-K)
            DEFINITION_CLEAN_BEFORE_BUILD='NO'
         ;;

         --static|--dynamic|--standalone)
            DEFINITION_PREFERRED_LIBRARY_STYLE="${argument:2}"
         ;;

         --shared)
            DEFINITION_PREFERRED_LIBRARY_STYLE="dynamic"
         ;;

         --platform)
            read -r DEFINITION_PLATFORM || fail "missing argument to \"${argument}\""
         ;;

         --preferred-library-style|--library-style)
            read -r DEFINITION_PREFERRED_LIBRARY_STYLE || fail "missing argument to \"${argument}\""
         ;;

         --library-style)
            read -r DEFINITION_LIBRARY_STYLE || fail "missing argument to \"${argument}\""
         ;;

         --log-dir)
            read -r DEFINITION_LOG_DIR || fail "missing argument to \"${argument}\""
         ;;

         -l|--load)
            read -r OPTION_LOAD || fail "missing argument to \"${argument}\""

            case "${MULLE_UNAME}" in
               mingw)
                   "${usage}"
               ;;
            esac
         ;;

         --path)
            read -r OPTION_PATH || fail "missing argument to \"${argument}\""
         ;;

         --phase)
            read -r OPTION_PHASE || fail "missing argument to \"${argument}\""
         ;;

         -s|--sdk)
            read -r DEFINITION_SDK || fail "missing argument to \"${argument}\""
         ;;

         --prefer-xcodebuild)
            DEFINITION_PREFER_XCODEBUILD='YES'
         ;;

         --rerun-cmake)
            OPTION_RERUN_CMAKE='YES'
         ;;

         --target|--targets)
            read -r DEFINITION_TARGETS || fail "missing argument to \"${argument}\""
         ;;

         --set-is-plus)
            OPTION_SET_IS_PLUS='YES'
         ;;

         --underline)
            OPTION_UNDERLINE='YES'
         ;;

         #
         # some special stuff separate from the rest for no good reason
         #
         --prefix)
            read -r DEFINITION_PREFIX || fail "missing argument to \"${argument}\""
            case "${DEFINITION_PREFIX}" in
               ""|/*)
               ;;

               *)
                  fail "--prefix \"${DEFINITION_PREFIX}\", prefix must be absolute or empty"
               ;;
            esac
         ;;

         # as in /Library/Frameworks:Frameworks etc.
         -F|--frameworks-path)
            read -r DEFINITION_FRAMEWORKS_PATH || fail "missing argument to \"${argument}\""
         ;;

         # as in /usr/include:/usr/local/include
         -I|--include-path)
            read -r DEFINITION_INCLUDE_PATH || fail "missing argument to \"${argument}\""
         ;;

         # as in /usr/lib:/usr/local/lib
         -L|--lib-path|--library-path)
            read -r DEFINITION_LIB_PATH || fail "missing argument to \"${argument}\""
         ;;

         -*)
            if ! make::definition::handle_definition_options "${argument}"
            then
               log_error "Unknown build option ${argument}"
               "${usage}"
            fi
         ;;

         *)
            break
         ;;
      esac
   done

   include "make::command"
   include "make::compiler"
   include "make::plugin"
   include "make::sdk"

   local srcdir

   # export some variables

   srcdir="${argument:-$PWD}"
   if [ ! -d "${srcdir}" ]
   then
      if [ ! -z "${MULLE_VIRTUAL_ROOT}" ]
      then
         case "${srcdir}" in
            */${MULLE_SOURCETREE_STASH_DIRNAME:-stash}/*)
               fail "Source directory \"${srcdir}\" is missing.
Maybe repair with:
   ${C_RESET_BOLD}mulle-sde clean fetch"
            ;;
         esac
      fi
      if [ -f "${srcdir}" ]
      then
         fail "\"${srcdir}\" is a file, but mulle-make wants a directory."
      fi
      fail "Source directory \"${srcdir}\" is missing."
   fi

   case "${cmd}" in
      clean)
         if read -r argument
         then
            log_error "Superflous argument \"${argument}\""
            make::build::clean_usage
         fi

         make::build::clean "${srcdir}" # not cleaning srcdir, dont't panic :)
         return $?
      ;;
   esac

   case "${OPTION_INFO_DIRS:-DEFAULT}" in
      'DEFAULT')
         if [ -d "${srcdir}/.mulle/etc/craft/definition" ]
         then
            OPTION_INFO_DIRS="${srcdir}/.mulle/etc/craft/definition"
         else
            OPTION_INFO_DIRS="${srcdir}/.mulle/share/craft/definition"
         fi
      ;;

      'NONE')
         unset OPTION_INFO_DIRS
      ;;
   esac

   case "${cmd}" in
      list)
         if read -r argument
         then
            log_error "Superflous argument \"${argument}\""
            make::build::list_usage
         fi
         make::build::list "${OPTION_INFO_DIRS}"
      ;;

      project)
         if read -r argument
         then
            log_error "Superflous argument \"${argument}\""
            make::build::project_usage
         fi

         make::build::build "build" \
                            "${srcdir}" \
                            "" \
                            "${OPTION_INFO_DIRS}" \
                            "${OPTION_SET_IS_PLUS}"
      ;;

      install)
         # DEFINITION_PREFIX is used for regular builds that do not install
         # if it is not defined, we require a destination directory
         local dstdir

         read -r dstdir
         if [ ! -z "${DEFINITION_PREFIX}" ]
         then
            dstdir="${DEFINITION_PREFIX:-${dstdir}}"
         fi

         if [ -z "${dstdir}" ]
         then
            log_fluff "Defaulting to install prefix \"/tmp\""
            dstdir="/tmp"
         fi

         if read -r argument
         then
            log_error "Superflous argument \"${argument}\""
            make::build::install_usage
         fi

         make::build::build "install" \
                            "${srcdir}" \
                            "${dstdir}" \
                            "${OPTION_INFO_DIRS}" \
                            "${OPTION_SET_IS_PLUS}"
      ;;
   esac
}


make::build::build_main()
{
   log_entry "make::build::build_main" "$@"

   usage="make::build::project_usage"
   make::build::common "project" "$1"
}


make::build::install_main()
{
   log_entry "make::build::install_main" "$@"

   usage="make::build::install_usage"
   make::build::common "install"
}


make::build::list_main()
{
   log_entry "make::build::list_main" "$@"

   usage="make::build::list_usage"
   make::build::common "list"
}


make::build::clean_main()
{
   log_entry "make::build::clean_main" "$@"

   usage="clean_usage"
   make::build::common "clean"
}
