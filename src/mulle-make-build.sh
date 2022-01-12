#! /usr/bin/env bash
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
MULLE_MAKE_BUILD_SH="included"


make::build::emit_common_options()
{
   local marks="$1"

   if [ "${marks}" = "common-prefix" ]
   then
      cat <<EOF
   --prefix <prefix>           : prefix to use for build products e.g. /usr/local
EOF
   fi

      cat <<EOF
   -D<key>=<value>             : set the definition named key to value
   -D<key>+=<value>            : append a += definition for the buildtool
   --build-dir <dir>           : specify build directory
   --debug                     : build with configuration "Debug"
   --include-path <path>       : specify header search PATH, separated by :
   --definition-dir <path>     : specify definition directory
   --aux-definition-dir <path> : specify auxiliar definition directory
   --dynamic                   : prefer dynamic library output
   --library-path <path>       : specify library search PATH, separated by :
   --no-ninja                  : prefer make over ninja
   --release                   : build with configuration "Release" (Default)
   --mulle-test                : build for mulle-test
   --verbose-make              : verbose make output
EOF
   case "${MULLE_UNAME}" in
      mingw*)
      ;;

      darwin)
         cat <<EOF
   --frameworks-path <path>    : specify Frameworks search PATH, separated by :
   -j <cores>                  : number of cores parameter for make (${MULLE_CORES})
EOF
      ;;

      *)
         cat <<EOF
   -j <cores>                  : number of cores parameter for make (${MULLE_CORES})
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
   though these definition directories.

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


make::build::install_usage()
{
   cat <<EOF >&2
Usage:
   ${MULLE_USAGE_NAME} install [options] [src] [dst]

   Build the project in the directory src. Then the build results are
   installed in dst.  If dst is omitted '/tmp' is used. If --prefix is 
   specified during options, do not specify dst as well.

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

   Do not build anything but list definitions as defined.

Options:
EOF
   make::build::emit_options "common-prefix" | LC_ALL=C sort

   exit 1
}


make::build::make_directories()
{
   local kitchendir="$1"
   local logsdir="$2"

   [ -z "${kitchendir}" ] && internal_fail "kitchendir is empty"

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
   [ ! -z "${configuration}" ] || internal_fail "configuration not defined"
   [ ! -z "${name}" ]          || internal_fail "name not defined"
   [ ! -z "${sdk}" ]           || internal_fail "sdk not defined"
   [ ! -z "${platform}" ]      || internal_fail "platform not defined"
   [ ! -z "${preference}" ]    || internal_fail "preference not defined"
   [ ! -z "${cmd}" ]           || internal_fail "cmd not defined"
   [ ! -z "${srcdir}" ]        || internal_fail "srcdir not defined"
# dstdir can be empty (check what DEFINITION_PREFIX does differently)
#   [ ! -z "${dstdir}" ]        || internal_fail "dstdir not defined"
   [ ! -z "${kitchendir}" ]      || internal_fail "kitchendir not defined"
   [ ! -z "${logsdir}" ]       || internal_fail "logsdir not defined"

   (
      local TOOLNAME="${preference}"
      local AUX_INFO

      local projectinfo

      if ! "make::plugin::${preference}::r_test" "${srcdir}"
      then
         return 127
      fi
      projectinfo="${RVAL}"

      [ -z "${projectinfo}" ] && \
         internal_fail "make::plugin::${preference}::r_test did not return projectinfo"
      #statements

      local blurb
      local conftext

      conftext="${configuration}"
      DEFINITION_LIBRARY_STYLE="${DEFINITION_LIBRARY_STYLE:-${DEFINITION_PREFERRED_LIBRARY_STYLE}}"
      if [ ! -z "${DEFINITION_LIBRARY_STYLE}" ]
      then
         conftext="${conftext}/${DEFINITION_LIBRARY_STYLE}"
      fi

      blurb="Let ${C_RESET_BOLD}${TOOLNAME}${C_INFO} do a \
${C_MAGENTA}${C_BOLD}${conftext}${C_INFO} build"
      if [ ! -z "${OPTION_PHASE}" ]
      then
         blurb="${blurb} ${C_MAGENTA}${C_BOLD}${OPTION_PHASE}${C_INFO} phase"
      fi
      blurb="${blurb} of \
${C_MAGENTA}${C_BOLD}${name}${C_INFO} for SDK \
${C_MAGENTA}${C_BOLD}${sdk}${C_INFO}${AUX_INFO} in \"${kitchendir#${PWD}/}\" ..."
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
         internal_fail "build_${preference} should exit on failure and not return"
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

   kitchendir="${DEFINITION_BUILD_DIR}"
   if [ -z "${kitchendir}" ]
   then
      kitchendir="`egrep -v '^#' "${markerfile}" 2> /dev/null`"
      if [ -z "${kitchendir}" ]
      then
         if [ ! -d "${srcdir}/build" ]
         then
            kitchendir="${srcdir}/build"
         else
            while :
            do
               local uuid
               local len=4 # turbo pedantic

               uuid="`uuidgen`" || internal_fail "uuidgen failed"
               kitchendir="${srcdir}/build-${uuid:0:${len}}"
               if [ ! -d "${kitchendir}" ]
               then
                  log_info "Use build directory ${C_RESET_BOLD}${kitchendir#${MULLE_USER_PWD}/}"
                  markerfile="${srcdir}/.mulle-make-build-dir"
                  break
               fi
               len=$(( len + 1 ))
            done
         fi
      fi
   fi

   logsdir="${DEFINITION_LOG_DIR:-${kitchendir}/.log}"

   make::build::make_directories "${kitchendir}" "${logsdir}"

   if [ ! -z "${markerfile}" ]
   then
      redirect_exekutor "${markerfile}" \
         echo "# memorizes the name-randomized build directory mulle-make uses
${kitchendir}"
   else
      remove_file_if_present "${srcdir}/.mulle-make-build-dir"
   fi

   # now known to exist, so we can canonicalize
   r_canonicalize_path "${kitchendir}"
   kitchendir="${RVAL}"

   r_canonicalize_path "${logsdir}"
   logsdir="${RVAL}"
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

   [ -z "${srcdir}" ]        && internal_fail "srcdir is empty"
   [ -z "${configuration}" ] && internal_fail "configuration is empty"
   [ -z "${sdk}" ]           && internal_fail "sdk is empty"
   [ -z "${platform}" ]      && internal_fail "platform is empty"
   [ -z "${preferences}" ]   && internal_fail "preferences is empty"

   if [ "${configuration}" = "lib" -o "${configuration}" = "include" -o "${configuration}" = "Frameworks" ]
   then
      fail "You are just asking for major trouble naming your configuration \"${configuration}\"."
   fi

   local name
   local kitchendir
   local logsdir

   make::build::__determine_directories

   local rval
   local preference

   .for preference in ${preferences}
   .do
      # pass local context w/o arguments
      make::build::__build_with_preference_if_possible

      rval="$?"
      if [ "${rval}" != 127 ]
      then
         return "${rval}"
      fi
   .done

   return 127
}


#
# used by plugins for environment calling cmake and friends.
#
make::build::r_env_flags()
{
   local env_flags

   r_concat "${env_flags}" "MULLE_MAKE_VERSION='${MULLE_EXECUTABLE_VERSION}'"

#   if [ ! -z "${MULLE_MAKE_PROJECT_DIR}" ]
#   then
#      env_flags="`concat "${env_flags}" "MULLE_MAKE_PROJECT_DIR='${MULLE_MAKE_PROJECT_DIR}'"`"
#   fi
#
#   if [ ! -z "${MULLE_MAKE_DESTINATION_DIR}" ]
#   then
#      env_flags="`concat "${env_flags}" "MULLE_MAKE_DESTINATION_DIR='${MULLE_MAKE_DESTINATION_DIR}'"`"
#   fi
}

make::build::clean()
{
   local srcdir="$1"

   make::build::__determine_directories

   rmdir_safer "${kitchendir}"
}


make::build::build()
{
   log_entry "make::build::build" "$@"

   local cmd="$1"
   local srcdir="$2"
   local dstdir="$3"
   local definitiondir="$4"
   local aux_definitiondir="$5"

   #
   # need these three defined before read_info_dir
   #
   r_simplified_absolutepath "${srcdir}"
   MULLE_MAKE_PROJECT_DIR="${RVAL}"
   r_simplified_absolutepath "${dstdir}"
   MULLE_MAKE_DESTINATION_DIR="${RVAL}"

   MULLE_MAKE_DEFINITION_DIR=
   MULLE_MAKE_AUX_DEFINITION_DIR=

   #
   # this is typically a definition in .mulle/etc|share/craft
   #
   if [ ! -z "${definitiondir}" ]
   then
      r_simplified_absolutepath "${definitiondir}"
      MULLE_MAKE_DEFINITION_DIR="${RVAL}"

      make::definition::read "${definitiondir}"
   fi

   #
   # this is typically a craftinfo in dependency/share
   #
   if [ ! -z "${aux_definitiondir}" ]
   then
      r_simplified_absolutepath "${aux_definitiondir}"
      MULLE_MAKE_AUX_DEFINITION_DIR="${RVAL}"

      make::definition::read "${aux_definitiondir}"
   fi

   local sdk

   sdk="${DEFINITION_SDK:-Default}"
   case "${sdk}" in
      Default)
         sdk="Default"
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
      if [ "${OPTION_ALLOW_SCRIPT}" != 'YES' ]
      then
         fail "No permission to run script \"${DEFINITION_BUILD_SCRIPT}\".
${C_INFO}Use --allow-script option or enable scripts permanently with:
${C_RESET_BOLD}   mulle-sde environment --global set MULLE_CRAFT_USE_SCRIPT YES"
      fi
      DEFINITION_PLUGIN_PREFERENCES="script"
      log_verbose "A script is defined, only considering a script build now"
   else
      log_fluff "No script defined"
   fi


   # used to receive values from make::plugin::loads
   local preferences

   make::plugin::r_loads "${DEFINITION_PLUGIN_PREFERENCES}" # can't be subshell !
   preferences="${RVAL}"

   if [ -z "${preferences}" ]
   then
      fail "Don't know how to build \"${srcdir}\".
There are no plugins available for requested tools \"`echo ${DEFINITION_PLUGIN_PREFERENCES}`\""
   fi

   log_fluff "Available mulle-make plugins for ${MULLE_UNAME} are: ${plugins}"


   make::build::build_with_sdk_platform_configuration_preferences "${cmd}" \
                                                                  "${srcdir}" \
                                                                  "${dstdir}" \
                                                                  "${sdk}" \
                                                                  "${platform}" \
                                                                  "${configuration}" \
                                                                  "${preferences}"
   case "$?" in
      0)
      ;;

      127)
         local pluginstring

         pluginstring="`sort <<< "${plugins}" | tr '\n' ',' `"
         fail "Don't know how to build \"${srcdir}\" with plugins ${pluginstring%%,}"
      ;;

      *)
         exit 1
      ;;
   esac
}


make::build::list()
{
   log_info "Definitions"

   local lf="
"
   make::definition::r_print "${DEFINED_SET_DEFINITIONS}" \
                             "${DEFINED_PLUS_DEFINITIONS}" \
                             "" \
                             "=" \
                             "+=" \
                             "" \
                             "" \
                       "${lf}"
   [ ! -z "${RVAL}" ] && printf "%s\n" "${RVAL}"

   :
}


make::build::common()
{
   log_entry "make::build::common" "$@"

   local cmd="${1:-project}"
   local argument="$2"

   [ -z "${DEFAULT_IFS}" ] && internal_fail "IFS fail"

   if [ -z "${MULLE_PARALLEL_SH}" ]
   then
      . "${MULLE_BASHFUNCTIONS_LIBEXEC_DIR}/mulle-parallel.sh" || return 1
   fi

   # will set MULLE_CORES
   r_get_core_count

   #
   # TODO: DEFINITIONS should not have DEFAULT values 
   #     
   local OPTION_ALLOW_UNKNOWN_OPTION

   local DEFINITION_CLEAN_BEFORE_BUILD
   local DEFINITION_CONFIGURATION
   local DEFINITION_DETERMINE_SDK
   local DEFINITION_SDK
   local DEFINITION_USE_NINJA
   local DEFINITION_PLATFORM
   local DEFINITION_LIBRARY_STYLE
   local DEFINITION_PREFERRED_LIBRARY_STYLE

   # why are these definitions ?
   local DEFINITION_BUILD_DIR
   local DEFINITION_LOG_DIR
   local DEFINITION_PREFIX

   local OPTION_INFO_DIR
   local OPTION_AUX_INFO_DIR
   local OPTION_ALLOW_SCRIPT
   local OPTION_CORES
   local OPTION_LOAD
   local OPTION_RERUN_CMAKE

   local state

   state='NEXT'
   if [ ! -z "${argument}" ]
   then
      state='FIRST'
   fi

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

         --allow-script)
            OPTION_ALLOW_SCRIPT='YES'
         ;;

         --no-allow-script)
            OPTION_ALLOW_SCRIPT='NO'
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

         --determine-sdk)
            DEFINITION_DETERMINE_SDK='YES'
         ;;

         --no-determine-sdk)
            DEFINITION_DETERMINE_SDK='NO'
         ;;

         --name|--project-name)
            read -r DEFINITION_PROJECT_NAME || fail "missing argument to \"${argument}\""
         ;;

         --language|--project-language)
            read -r DEFINITION_PROJECT_LANGUAGE || fail "missing argument to \"${argument}\""
         ;;

         --plugins|--plugin-preferences|--tools|--tool-preferences)
            read -r argument || fail "missing argument to \"${argument}\""

            # convenient to allow empty parameter here (for mulle-bootstrap)
            if [ ! -z "${argument}" ]
            then
               DEFINITION_PLUGIN_PREFERENCES="${argument}"
            fi
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

         -d|--definition-dir|--info-dir|--makeinfo-dir)
            read -r OPTION_INFO_DIR || fail "missing argument to \"${argument}\""
         ;;

         --aux-definition-dir)
            read -r OPTION_AUX_INFO_DIR || fail "missing argument to \"${argument}\""
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

         --platform)
            read -r DEFINITION_PLATFORM || fail "missing argument to \"${argument}\""
         ;;

         --phase)
            read -r OPTION_PHASE || fail "missing argument to \"${argument}\""
         ;;

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

         --prefer-xcodebuild)
            DEFINITION_PREFER_XCODEBUILD='YES'
         ;;

         --rerun-cmake)
            OPTION_RERUN_CMAKE='YES'
         ;;

         -s|--sdk)
            read -r DEFINITION_SDK || fail "missing argument to \"${argument}\""
         ;;

         '-D'*'+='*)
            if [ -z "${MULLE_MAKE_DEFINITION_SH}" ]
            then
               . "${MULLE_MAKE_LIBEXEC_DIR}/mulle-make-definition.sh" || return 1
            fi

            #
            # allow multiple -D+= values to appen values
            # useful for -DCFLAGS+= the most often used flag
            #
            make::definition::make_define_plus_keyvalue "${argument:2}" "append"
         ;;

         '-D'*)
            if [ -z "${MULLE_MAKE_DEFINITION_SH}" ]
            then
               . "${MULLE_MAKE_LIBEXEC_DIR}/mulle-make-definition.sh" || return 1
            fi

            make::definition::make_define_set_keyvalue "${argument:2}"
         ;;

         '--ifempty'|'--append'|'--append0'|'--remove')
            if [ -z "${MULLE_MAKE_DEFINITION_SH}" ]
            then
               . "${MULLE_MAKE_LIBEXEC_DIR}/mulle-make-definition.sh" || return 1
            fi

            read -r keyvalue || fail "missing argument to \"${argument}\""
            case "${keyvalue}" in
               *'+='*)
                  make::definition::make_define_plus_keyvalue "${keyvalue}" "${argument:2}"
               ;;

               *)
                  make::definition::make_define_set_keyvalue "${keyvalue}" "${argument:2}"
               ;;
            esac
         ;;

         '-U'*)
            if [ -z "${MULLE_MAKE_DEFINITION_SH}" ]
            then
               . "${MULLE_MAKE_LIBEXEC_DIR}/mulle-make-definition.sh" || return 1
            fi

            make::definition::make_undefine_option "${argument:2}"
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
            log_error "Unknown build option ${argument}"
            "${usage}"
         ;;

         *)
            break
         ;;
      esac
   done

   if [ -z "${MULLE_MAKE_COMMON_SH}" ]
   then
      . "${MULLE_MAKE_LIBEXEC_DIR}/mulle-make-common.sh" || return 1
   fi

   if [ -z "${MULLE_MAKE_DEFINITION_SH}" ]
   then
      . "${MULLE_MAKE_LIBEXEC_DIR}/mulle-make-definition.sh" || return 1
   fi

   if [ -z "${MULLE_MAKE_COMMAND_SH}" ]
   then
      . "${MULLE_MAKE_LIBEXEC_DIR}/mulle-make-command.sh" || return 1
   fi

   if [ -z "${MULLE_MAKE_COMPILER_SH}" ]
   then
      . "${MULLE_MAKE_LIBEXEC_DIR}/mulle-make-compiler.sh" || return 1
   fi

   if [ -z "${MULLE_MAKE_PLUGIN_SH}" ]
   then
      . "${MULLE_MAKE_LIBEXEC_DIR}/mulle-make-plugin.sh" || return 1
   fi

   if [ -z "${MULLE_MAKE_SDK_SH}" ]
   then
      . "${MULLE_MAKE_LIBEXEC_DIR}/mulle-make-sdk.sh" || return 1
   fi

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
   ${C_RESET_BOLD}mulle-sde make::build::clean fetch"
            ;;
         esac
      fi
      fail "Source directory \"${srcdir}\" is missing"
   fi

   case "${cmd}" in
      clean)
         if read -r argument
         then
            log_error "Superflous argument \"${argument}\""
            make::build::project_usage
         fi

         make::build::clean "${srcdir}" # not cleaning srcdir, dont't panic :)
         return $?
      ;;
   esac

   case "${OPTION_INFO_DIR:-Default}" in
      'Default')
         OPTION_INFO_DIR="${srcdir}/.mulle/etc/craft/definition"
      ;;

      'NONE')
         unset OPTION_INFO_DIR
      ;;
   esac

   case "${cmd}" in
      list)
         if read -r argument
         then
            log_error "Superflous argument \"${argument}\""
            make::build::list_usage
         fi
         make::build::list
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
               "${OPTION_INFO_DIR}" \
               "${OPTION_AUX_INFO_DIR}"
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
               "${OPTION_INFO_DIR}" \
               "${OPTION_AUX_INFO_DIR}"
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
