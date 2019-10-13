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


_emit_common_options()
{
   local marks="$1"

   if [ "${marks}" = "common-prefix" ]
   then
      cat <<EOF
   --prefix <prefix>          : prefix to use for build products e.g. /usr/local
EOF
   fi

      cat <<EOF
   --append <key>[+]=<value>  : like -D, but appends value to a previous value
   -D<key>=<value>            : set the definition named key to value
   -D<key>+=<value>           : append a += definition for the buildtool
   --build-dir <dir>          : specify build directory
   --debug                    : build with configuration "Debug"
   --ifempty <key>[+]=<value> : like -D, but only if no previous value exists
   --include-path <path>      : specify header search PATH, separated by :
   --definition-dir <path>    : specify definition directory
   --library-style <type>     : produced type : static,dynamic,standalone
   --library-path <path>      : specify library search PATH, separated by :
   --release                  : build with configuration "Release" (Default)
   --remove<key>[+]=<value>   : like -D,but removes value from a previous value
   -U<key>                    : undefine a definition or += definition
   --test                     : build with configuration "Test"
   --verbose-make             : verbose make output
EOF
   case "${MULLE_UNAME}" in
      mingw*)
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


_emit_uncommon_options()
{
   local marks="$1"

   if [ "${marks}" != "common-prefix" ]
   then
      cat <<EOF
   --prefix <prefix>          : prefix to use for build products e.g. /usr/local
EOF
   fi

   cat <<EOF
   --configuration <name>     : configuration to build like Debug or Release
   --clean                    : always clean before building
   --log-dir <dir>            : specify log directory
   --no-determine-sdk         : don't try to figure out the default SDK
   --no-ninja                 : prefer make over ninja
   --phase <name>             : run make phase (for parallel builds)
   --project-name <name>      : explicitly set project name
   --project-language <c|cpp> : set project language
   --sdk <name>               : SDK to use (Default)
   --tool-preferences <list>  : tool preference order. Tools are separated by ','
EOF
   case "${MULLE_UNAME}" in
      darwin)
         echo "\
   --xcode-config-file <file> : specify xcode config file to use"
      ;;
   esac
}


emit_options()
{
   local marks="$1"

   if [ "${MULLE_FLAG_LOG_VERBOSE}" = 'YES' ]
   then
      _emit_uncommon_options "${marks}"
   fi
   _emit_common_options "${marks}"
}


project_usage()
{
   cat <<EOF >&2
Usage:
   ${MULLE_USAGE_NAME} project [options] [directory]

   Build the project in directory. If directory is omitted, the current
   directory is used.

Options:
EOF
   emit_options | LC_ALL=C sort

   exit 1
}


install_usage()
{
   cat <<EOF >&2
Usage:
   ${MULLE_USAGE_NAME} install [options] [srcdir] [dstdir]

   Build the project in src. Then the build results are installed in
   dst.  If dst is omitted '/tmp' is used. If --prefix is specified, do not
   specify dst.

Options:
EOF
   emit_options "common-prefix" | LC_ALL=C sort

   exit 1
}


list_usage()
{
   cat <<EOF >&2
Usage:
   ${MULLE_USAGE_NAME} list [options]

   Do not build anything but list definitions as defined.

Options:
EOF
   emit_options "common-prefix" | LC_ALL=C sort

   exit 1
}


mkdir_build_directories()
{
   local kitchendir="$1"
   local logsdir="$2"

   [ -z "${kitchendir}" ] && internal_fail "kitchendir is empty"

   if [ -d "${kitchendir}" -a "${OPTION_CLEAN_BEFORE_BUILD}" = 'YES' ]
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
build_with_preference_if_possible()
{
   [ ! -z "${configuration}" ] || internal_fail "configuration not defined"
   [ ! -z "${name}" ]          || internal_fail "name not defined"
   [ ! -z "${sdk}" ]           || internal_fail "sdk not defined"
   [ ! -z "${platform}" ]      || internal_fail "platform not defined"
   [ ! -z "${preference}" ]    || internal_fail "preference not defined"
   [ ! -z "${cmd}" ]           || internal_fail "cmd not defined"
   [ ! -z "${srcdir}" ]        || internal_fail "srcdir not defined"
# dstdir can be empty (check what OPTION_PREFIX does differently)
#   [ ! -z "${dstdir}" ]        || internal_fail "dstdir not defined"
   [ ! -z "${kitchendir}" ]      || internal_fail "kitchendir not defined"
   [ ! -z "${logsdir}" ]       || internal_fail "logsdir not defined"

   (
      local TOOLNAME="${preference}"
      local AUX_INFO

      local projectinfo

      if ! "r_test_${preference}" "${srcdir}"
      then
         return 127
      fi
      projectinfo="${RVAL}"

      [ -z "${projectinfo}" ] && \
         internal_fail "r_test_${preference} did not return projectinfo"
      #statements

      local blurb
      local conftext

      conftext="${configuration}"
      OPTION_LIBRARY_STYLE="${OPTION_LIBRARY_STYLE:-${OPTION_PREFERRED_LIBRARY_STYLE}}"
      if [ ! -z "${OPTION_LIBRARY_STYLE}" ]
      then
         conftext="${conftext}/${OPTION_LIBRARY_STYLE}"
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

      if ! "build_${preference}" "${cmd}" \
                                 "${projectinfo}" \
                                 "${sdk}" \
                                 "${platform}" \
                                 "${configuration}" \
                                 "${srcdir}" \
                                 "${dstdir}" \
                                 "${kitchendir}" \
                                 "${logsdir}"
      then
         log_error "build_${preference} should exit on failure and not return"
         return 1
      fi
   )
}


build_with_sdk_platform_configuration_preferences()
{
   log_entry "build_with_sdk_platform_configuration_preferences" "$@"

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

   name="${OPTION_PROJECT_NAME}"
   if [ -z "${name}" ]
   then
      r_basename "${srcdir}"
      name="${RVAL}"
   fi

   #
   # remove symlinks
   #
   srcdir="`canonicalize_path "${srcdir}"`"

   local kitchendir

   kitchendir="${OPTION_BUILD_DIR}"
   if [ -z "${kitchendir}" ]
   then
      kitchendir="${srcdir}/build"
   fi

   local logsdir

   logsdir="${OPTION_LOG_DIR}"
   if [ -z "${logsdir}" ]
   then
      logsdir="${kitchendir}/.log"
   fi

   mkdir_build_directories "${kitchendir}" "${logsdir}"

   # now known to exist, so we can canonialize
   kitchendir="`canonicalize_path "${kitchendir}"`"
   logsdir="`canonicalize_path "${logsdir}"`"

   local rval
   local preference

   set -o noglob
   for preference in ${preferences}
   do
      set +o noglob
      # pass local context w/o arguments
      build_with_preference_if_possible

      rval="$?"
      if [ "${rval}" != 127 ]
      then
         return "${rval}"
      fi
   done
   set +o noglob

   return 127
}


#
# used by plugins for environment calling cmake and friends.
#
r_mulle_make_env_flags()
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


build()
{
   log_entry "build" "$@"

   local cmd="$1"
   local srcdir="$2"
   local dstdir="$3"
   local definitiondir="$4"

   #
   # need these three defined before read_info_dir
   #
   r_simplified_absolutepath "${srcdir}"
   MULLE_MAKE_PROJECT_DIR="${RVAL}"
   r_simplified_absolutepath "${dstdir}"
   MULLE_MAKE_DESTINATION_DIR="${RVAL}"
   MULLE_MAKE_DEFINITION_DIR=

   if [ ! -z "${definitiondir}" ]
   then
      r_simplified_absolutepath "${definitiondir}"
      MULLE_MAKE_DEFINITION_DIR="${RVAL}"

      read_definition_dir "${definitiondir}"
   fi

   #
   # If we have a script, can we use it ?
   # If yes, we only use the script and fail for every other plugin
   #
   if [ ! -z "${OPTION_BUILD_SCRIPT}" ]
   then
      if [ "${OPTION_ALLOW_SCRIPT}" != 'YES' ]
      then
         fail "No permission to run script \"${OPTION_BUILD_SCRIPT}\".
${C_INFO}Use --allow-script option or enable scripts permanently with:
${C_RESET_BOLD}   mulle-sde environment --global set MULLE_CRAFT_USE_SCRIPT YES"
      fi
      OPTION_PLUGIN_PREFERENCES="script"
      log_verbose "A script is defined, only considering a script build now"
   else
      log_debug "No script defined"
   fi


   # used to receive values from build_load_plugins
   local AVAILABLE_PLUGINS

   build_load_plugins "${OPTION_PLUGIN_PREFERENCES}" # can't be subshell !
   if [ -z "${AVAILABLE_PLUGINS}" ]
   then
      fail "Don't know how to build \"${srcdir}\".
There are no plugins available for requested tools \"`echo ${OPTION_PLUGIN_PREFERENCES}`\""
   fi

   log_fluff "Available mulle-make plugins for ${MULLE_UNAME} are: `echo ${AVAILABLE_PLUGINS}`"

   local sdk

   sdk="${OPTION_SDK}"
   case "${sdk}" in
      DEFAULT)
         sdk="Default"
      ;;

      maosx)
         case "${MULLE_UNAME}" in
            darwin)
               sdk="Default"
            ;;
         esac
      ;;

      "")
         fail "An Empty sdk is not possible (use \"Default\")"
      ;;
   esac

   local platform

   platform="${OPTION_PLATFORM}"
   case "${platform}" in
      DEFAULT)
         platform="Default"
      ;;

      "")
         fail "An empty platform is not possible (use \"Default\")"
      ;;
   esac

   local configuration

   configuration="${OPTION_CONFIGURATION}"
   case "${configuration}" in
      DEFAULT)
         configuration="Release"
      ;;

      "")
         fail "An empty configuration is not possible (use \"Release\")"
      ;;
   esac

   build_with_sdk_platform_configuration_preferences "${cmd}" \
                                                     "${srcdir}" \
                                                     "${dstdir}" \
                                                     "${sdk}" \
                                                     "${platform}" \
                                                     "${configuration}" \
                                                     "${AVAILABLE_PLUGINS}"
   case "$?" in
      0)
      ;;

      127)
         fail "Don't know how to build \"${srcdir}\" with plugins \"${AVAILABLE_PLUGINS}\""
      ;;

      *)
         exit 1
      ;;
   esac
}


list_main()
{
   log_info "Definitions"

   local lf="
"
   r_print_definitions "${DEFINED_OPTIONS}" \
                       "${DEFINED_PLUS_OPTIONS}" \
                       "" \
                       "=" \
                       "+=" \
                       "" \
                       "" \
                       "${lf}"
   [ ! -z "${RVAL}" ] && printf "%s\n" "${RVAL}"

   :
}


_make_build_main()
{
   log_entry "_make_build_main" "$@"

   local cmd="${1:-project}"
   local argument="$2"

   [ -z "${DEFAULT_IFS}" ] && internal_fail "IFS fail"

   if [ -z "${MULLE_PARALLEL_SH}" ]
   then
      . "${MULLE_BASHFUNCTIONS_LIBEXEC_DIR}/mulle-parallel.sh" || return 1
   fi

   # will set MULLE_CORES
   r_get_core_count

   local OPTION_PLUGIN_PREFERENCES='DEFAULT'
   local OPTION_ALLOW_UNKNOWN_OPTION="DEFAULT"
   local OPTION_CLEAN_BEFORE_BUILD="DEFAULT"
   local OPTION_CONFIGURATION="DEFAULT"
   local OPTION_DETERMINE_SDK="DEFAULT"
   local OPTION_SDK="DEFAULT"
   local OPTION_NINJA="DEFAULT"
   local OPTION_PLATFORM="DEFAULT"

   local OPTION_BUILD_DIR
   local OPTION_LOG_DIR
   local OPTION_PREFIX
   local OPTION_INFO_DIR="DEFAULT"
   local OPTION_ALLOW_SCRIPT="DEFAULT"
   local OPTION_CORES
   local OPTION_LOAD
   local OPTION_LIBRARY_STYLE
   local OPTION_PREFERRED_LIBRARY_STYLE

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
            OPTION_CONFIGURATION="Debug"
         ;;

         --release)
            OPTION_CONFIGURATION="Release"
         ;;

         --test)
            OPTION_CONFIGURATION="Test"
         ;;

         --ninja)
            OPTION_NINJA='YES'
         ;;

         --no-ninja)
            OPTION_NINJA='NO'
         ;;

         --determine-sdk)
            OPTION_DETERMINE_SDK='YES'
         ;;

         --no-determine-sdk)
            OPTION_DETERMINE_SDK='NO'
         ;;

         --name|--project-name)
            read -r OPTION_PROJECT_NAME || fail "missing argument to \"${argument}\""
         ;;

         --language|--project-language)
            read -r OPTION_PROJECT_LANGUAGE || fail "missing argument to \"${argument}\""
         ;;

         --tools|--tool-preferences)
            read -r argument || fail "missing argument to \"${argument}\""

            # convenient to allow empty parameter here (for mulle-bootstrap)
            if [ ! -z "${argument}" ]
            then
               OPTION_PLUGIN_PREFERENCES="${argument}"
            fi
         ;;

         --xcode-config-file)
            read -r OPTION_XCODE_XCCONFIG_FILE || fail "missing argument to \"${argument}\""
         ;;

         #
         # with shortcuts
         #
         --build-dir)
            read -r OPTION_BUILD_DIR || fail "missing argument to \"${argument}\""
         ;;

         -c|--configuration)
            read -r OPTION_CONFIGURATION || fail "missing argument to \"${argument}\""
         ;;

         -d|--definition-dir|--info-dir|--makeinfo-dir)
            read -r OPTION_INFO_DIR || fail "missing argument to \"${argument}\""
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
            OPTION_CLEAN_BEFORE_BUILD='YES'
         ;;

         --no-clean|-K)
            OPTION_CLEAN_BEFORE_BUILD='NO'
         ;;

         --preferred-library-style)
            read -r OPTION_PREFERRED_LIBRARY_STYLE || fail "missing argument to \"${argument}\""
         ;;

         --library-style)
            read -r OPTION_LIBRARY_STYLE || fail "missing argument to \"${argument}\""
         ;;


         --log-dir)
            read -r OPTION_LOG_DIR || fail "missing argument to \"${argument}\""
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
            read -r OPTION_PLATFORM || fail "missing argument to \"${argument}\""
         ;;

         --phase)
            read -r OPTION_PHASE || fail "missing argument to \"${argument}\""
         ;;

         --prefix)
            read -r OPTION_PREFIX || fail "missing argument to \"${argument}\""
            case "${OPTION_PREFIX}" in
               ""|/*)
               ;;

               *)
                  fail "--prefix \"${OPTION_PREFIX}\", prefix must be absolute or empty"
               ;;
            esac
         ;;

         -s|--sdk)
            read -r OPTION_SDK || fail "missing argument to \"${argument}\""
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
            make_define_plusoption_keyvalue "${argument:2}" "append"
         ;;

         '-D'*)
            if [ -z "${MULLE_MAKE_DEFINITION_SH}" ]
            then
               . "${MULLE_MAKE_LIBEXEC_DIR}/mulle-make-definition.sh" || return 1
            fi

            make_define_option_keyvalue "${argument:2}"
         ;;

         '--ifempty'|'--append'|'--append0'|'--remove')
            if [ -z "${MULLE_MAKE_DEFINITION_SH}" ]
            then
               . "${MULLE_MAKE_LIBEXEC_DIR}/mulle-make-definition.sh" || return 1
            fi

            read -r keyvalue || fail "missing argument to \"${argument}\""
            case "${keyvalue}" in
               *'+='*)
                  make_define_plusoption_keyvalue "${keyvalue}" "${argument:2}"
               ;;

               *)
                  make_define_option_keyvalue "${keyvalue}" "${argument:2}"
               ;;
            esac
         ;;

         '-U'*)
            if [ -z "${MULLE_MAKE_DEFINITION_SH}" ]
            then
               . "${MULLE_MAKE_LIBEXEC_DIR}/mulle-make-definition.sh" || return 1
            fi

            make_undefine_option "${argument:2}"
         ;;

         # as in /Library/Frameworks:Frameworks etc.
         -F|--frameworks-path)
            read -r OPTION_FRAMEWORKS_PATH || fail "missing argument to \"${argument}\""
         ;;

         # as in /usr/include:/usr/local/include
         -I|--include-path)
            read -r OPTION_INCLUDE_PATH || fail "missing argument to \"${argument}\""
         ;;

         # as in /usr/lib:/usr/local/lib
         -L|--lib-path|--library-path)
            read -r OPTION_LIB_PATH || fail "missing argument to \"${argument}\""
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

   if [ "${OPTION_PLUGIN_PREFERENCES}" = 'DEFAULT' ]
   then
      OPTION_PLUGIN_PREFERENCES='cmake:meson:autoconf:configure'
      case "${MULLE_UNAME}" in
         darwin)
            if [ "${OPTION_PREFER_XCODEBUILD}" = 'YES' ]
            then
               OPTION_PLUGIN_PREFERENCES="xcodebuild:${OPTION_PLUGIN_PREFERENCES}"
            else
               OPTION_PLUGIN_PREFERENCES="${OPTION_PLUGIN_PREFERENCES}:xcodebuild"
            fi
         ;;
      esac
   fi

   local srcdir

   # export some variables

   srcdir="${argument:-$PWD}"
   if [ ! -d "${srcdir}" ]
   then
      if [ ! -z "${MULLE_VIRTUAL_ROOT}" ]
      then
         case "${srcdir}" in
            */stash/*)
               fail "Source directory \"${srcdir}\" is missing.
Maybe repair with:
   ${C_RESET_BOLD}mulle-sde clean fetch"
            ;;
         esac
      fi
      fail "Source directory \"${srcdir}\" is missing"
   fi

   case "${OPTION_INFO_DIR}" in
      'DEFAULT')
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
            list_usage
         fi
         list_main
      ;;

      project)
         if read -r argument
         then
            log_error "Superflous argument \"${argument}\""
            project_usage
         fi

         build "build" \
               "${srcdir}" \
               "" \
               "${OPTION_INFO_DIR}"
      ;;

      install)
         # OPTION_PREFIX is used for regular builds that do not install
         # if it is not defined, we require a destination directory
         local dstdir

         read -r dstdir
         if [ ! -z "${OPTION_PREFIX}" ]
         then
            if [ -z "${dstdir}" ]
            then
               dstdir="${OPTION_PREFIX}"
            fi
         fi

         if [ -z "${dstdir}" ]
         then
            log_fluff "Defaulting to install prefix \"/tmp\""
            dstdir="/tmp"
         fi

         if read -r argument
         then
            log_error "Superflous argument \"${argument}\""
            install_usage
         fi

         build "install" \
               "${srcdir}" \
               "${dstdir}" \
               "${OPTION_INFO_DIR}"
      ;;
   esac
}


make_build_main()
{
   log_entry "make_build_main" "$@"

   usage="project_usage"
   _make_build_main "project" "$1"
}


make_install_main()
{
   log_entry "make_install_main" "$@"

   usage="install_usage"
   _make_build_main "install"
}


make_list_main()
{
   log_entry "make_list_main" "$@"

   usage="list_usage"
   _make_build_main "list"
}
