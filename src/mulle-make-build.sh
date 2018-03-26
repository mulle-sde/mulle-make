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
   cat <<EOF
   -D<key>=<value>            : set definition (can't mix with += definitions)
   -D<key>+=<value>           : add to definition
   --build-dir <dir>          : specify build directory
   --info-dir <path>          : specify info directory
   --debug                    : build with configuration Debug
   --include-path <path>      : specify header search PATH, separated by :
   --lib-path <path>          : specify library search PATH, separated by :
   --release                  : build with configuration Release (Default)
   --verbose-make             : verbose make output
EOF

   case "${UNAME}" in
      mingw*)
      ;;

      darwin)
         cat <<EOF
   --frameworks-path <path>   : specify Frameworks search PATH, separated by :
   -j                         : number of cores parameter for make (${CORES})
EOF
      ;;

      *)
         cat <<EOF
   -j                         : number of cores parameter for make (${CORES})
EOF
      ;;
   esac
}


_emit_uncommon_options()
{
   cat <<EOF
   --configuration <name>     : configuration to build like Debug or Release
   -K                         : always clean before building
   -k                         : don't clean before building
   --no-ninja                 : prefer make over ninja
   --log-dir <dir>            : specify log directory
   --prefix <prefix>          : prefix to use for build products e.g. /usr/local
   --project-name <name>      : explicitly set project name
   --sdk <name>               : SDK to use (Default)
   --tool-preferences <list>  : tool preference order. Tools are separated by ','
EOF
   case "${UNAME}" in
      darwin)
         echo "\
   --no-determine-xcode-sdk   : don't use xcrun to figure out Xcode SDK to use
   --xcode-config-file <file> : specify xcode config file to use"
      ;;
   esac
}


emit_options()
{
   if [ "${MULLE_FLAG_LOG_VERBOSE}" = "YES" ]
   then
      _emit_common_options
   fi
   _emit_uncommon_options
}


build_usage()
{
   cat <<EOF >&2
Usage:
   ${MULLE_USAGE_NAME} build [options] [directory]

   Build the project in directory. If directory is omitted, the current
   directory is used.

Options:
EOF
   emit_options | sort

   exit 1
}


install_usage()
{
   cat <<EOF >&2
Usage:
   ${MULLE_USAGE_NAME} install [options] <src> [dst]

   Build the project in src. Then the build results are installed in
   dst.  If dst is omitted '/tmp' is used.

Options:
EOF
   emit_options | sort

   exit 1
}


mkdir_build_directories()
{
   local builddir="$1"
   local logsdir="$2"

   [ -z "${builddir}" ] && internal_fail "builddir is empty"

   if [ -d "${builddir}" -a "${OPTION_CLEAN_BEFORE_BUILD}" = "YES" ]
   then
      log_fluff "Cleaning build directory \"${builddir}\""
      rmdir_safer "${builddir}"
   else
      mkdir_if_missing "${builddir}"
   fi

   mkdir_if_missing "${logsdir}"
}


determine_build_subdir()
{
   log_entry "determine_build_subdir" "$@"

   local configuration="$1"
   local sdk="$2"

   [ -z "$configuration" ] && internal_fail "configuration must not be empty"
   [ -z "$sdk" ]           && internal_fail "sdk must not be empty"

   sdk=`echo "${sdk}" | "${SED:-sed}" 's/^\([a-zA-Z]*\).*$/\1/g'`

   if [ "${sdk}" = "Default" ]
   then
      if [ "${configuration}" != "Release" ]
      then
         echo "${configuration}"
      fi
   else
      echo "${configuration}-${sdk}"
   fi
}


#
# 0 OK
# 255 preference does not support it
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
   [ ! -z "${preference}" ]    || internal_fail "preference not defined"
   [ ! -z "${cmd}" ]           || internal_fail "cmd not defined"
   [ ! -z "${srcdir}" ]        || internal_fail "srcdir not defined"
# dstdir can be empty (check what OPTION_PREFIX does differently)
#   [ ! -z "${dstdir}" ]        || internal_fail "dstdir not defined"
   [ ! -z "${builddir}" ]      || internal_fail "builddir not defined"
   [ ! -z "${logsdir}" ]       || internal_fail "logsdir not defined"

   (
      local WASXCODE="NO"
      local PROJECTFILE
      local TOOLNAME="${preference}"
      local AUX_INFO

      if ! "test_${preference}" "${configuration}" "${srcdir}"
      then
         return 255
      fi

      [ -z "${PROJECTFILE}" ] && \
         internal_fail "test_${preference} did not set PROJECTFILE"
      #statements

      log_info "Let ${C_RESET_BOLD}${TOOLNAME}${C_INFO} do a \
${C_MAGENTA}${C_BOLD}${configuration}${C_INFO} build of \
${C_MAGENTA}${C_BOLD}${name}${C_INFO} for SDK \
${C_MAGENTA}${C_BOLD}${sdk}${C_INFO}${AUX_INFO} in \"${builddir}\" ..."

      if ! "build_${preference}" "${cmd}" \
                                 "${PROJECTFILE}" \
                                 "${configuration}" \
                                 "${srcdir}" \
                                 "${dstdir}" \
                                 "${builddir}" \
                                 "${logsdir}" \
                                 "${sdk}"
      then
         log_error "build_${preference} should exit on failure and not return"
         return 1
      fi
   )
}


build_with_configuration_sdk_preferences()
{
   log_entry "build_with_configuration_sdk_preferences" "$@"

   local cmd="$1"; shift

   local srcdir="$1"
   local dstdir="$2"
   local configuration="$3"
   local sdk="$4"
   local preferences="$5"

   [ -z "${srcdir}" ]        && internal_fail "srcdir is empty"
   [ -z "${configuration}" ] && internal_fail "configuration is empty"
   [ -z "${sdk}" ]           && internal_fail "sdk is empty"
   [ -z "${preferences}" ]   && internal_fail "preferences is empty"

   if [ "${configuration}" = "lib" -o "${configuration}" = "include" -o "${configuration}" = "Frameworks" ]
   then
      fail "You are just asking for major trouble naming your configuration \"${configuration}\"."
   fi

   local name

   name="`basename -- "${srcdir}"`"

   #
   # remove symlinks
   #
   srcdir="`canonicalize_path "${srcdir}"`"

   local builddir
   local buildroot

   buildroot="${OPTION_BUILD_DIR}"
   builddir="${buildroot}"

   local build_subdir

   build_subdir="`determine_build_subdir "${configuration}" "${sdk}"`" || exit 1

   if [ -z "${builddir}" ]
   then
      buildroot="${srcdir}/build"
      builddir="`filepath_concat "${buildroot}" "${build_subdir}" `"
   fi

   local logsdir

   logsdir="${OPTION_LOG_DIR}"
   if [ -z "${logsdir}" ]
   then
      logsdir="${buildroot}/logs"
      logsdir="`filepath_concat "${logsdir}" "${build_subdir}" `"
   fi

   mkdir_build_directories "${builddir}" "${logsdir}"

   # now known to exist, so we can canonialize
   builddir="`canonicalize_path "${builddir}"`"
   logsdir="`canonicalize_path "${logsdir}"`"

   local BUILDPATH

   BUILDPATH="${OPTION_PATH:-$PATH}"

   local rval
   local preference

   set -o noglob
   for preference in ${preferences}
   do
      set +o noglob
      # pass local context w/o arguments
      build_with_preference_if_possible

      rval="$?"
      if [ "${rval}" != 255 ]
      then
         return "${rval}"
      fi
   done
   set +o noglob

   return 255
}


build()
{
   log_entry "build" "$@"

   local cmd="$1"
   local srcdir="$2"
   local dstdir="$3"

   # used to receive values from build_load_plugins
   local AVAILABLE_PLUGINS

   build_load_plugins "${OPTION_TOOL_PREFERENCES}" # can't be subshell !
   if [ -z "${AVAILABLE_PLUGINS}" ]
   then
      fail "Don't know how to build \"${srcdir}\".
There are no plugins available for requested tools \"`echo ${OPTION_TOOL_PREFERENCES}`\""
   fi

   log_fluff "Actually available plugins for ${UNAME} are: `echo ${AVAILABLE_PLUGINS}`"

   local sdk

   sdk="${OPTION_SDK}"
   case "${sdk}" in
      DEFAULT)
         sdk="Default"
      ;;

      maosx)
         case "${UNAME}" in
            darwin)
               sdk="Default"
            ;;
         esac
      ;;

      "")
         fail "empty sdk is not possible"
      ;;
   esac

   local configuration

   configuration="${OPTION_CONFIGURATION}"
   case "${configuration}" in
      DEFAULT)
         configuration="Release"
      ;;

      "")
         fail "empty configuration is not possible"
      ;;
   esac

   build_with_configuration_sdk_preferences "${cmd}" \
                                            "${srcdir}" \
                                            "${dstdir}" \
                                            "${configuration}" \
                                            "${sdk}" \
                                            "${AVAILABLE_PLUGINS}"

   case "$?" in
      0)
      ;;

      255)
         fail "Don't know how to build \"${srcdir}\""
      ;;

      *)
         exit 1
      ;;
   esac
}



#
# grep through project to get the options:_
# egrep -h -o -w 'OPTION_[A-Z0-9_]*[A-Z0-9]' src/*.sh src/plugins/*.sh | sort -u
#
KNOWN_AUTOCONF_PLUGIN_OPTIONS="\
OPTION_AUTOCONF
OPTION_AUTORECONF
OPTION_AUTOCONFFLAGS
OPTION_AUTORECONFFLAGS"

KNOWN_CMAKE_PLUGIN_OPTIONS="\
OPTION_CMAKE
OPTION_CMAKEFLAGS
OPTION_CMAKE_GENERATOR"

KNOWN_CONFIGURE_PLUGIN_OPTIONS="\
OPTION_CONFIGUREFLAGS"

KNOWN_MESON_PLUGIN_OPTIONS="\
OPTION_MESON
OPTION_MESONFLAGS
OPTION_MESON_BACKEND"

KNOWN_XCODEBUILD_PLUGIN_OPTIONS="\
OPTION_XCODEBUILD"


KNOWN_GENERAL_OPTIONS="\
OPTION_BUILD_DIR
OPTION_CC
OPTION_CFLAGS
OPTION_CLEAN_BEFORE_BUILD
OPTION_CONFIGURATION
OPTION_CXX
OPTION_CXXFLAGS
OPTION_DETERMINE_XCODE_SDK
OPTION_FRAMEWORKS_PATH
OPTION_GCC_PREPROCESSOR_DEFINITIONS
OPTION_INCLUDE_PATH
OPTION_LDFLAGS
OPTION_LIB_PATH
OPTION_LOG_DIR
OPTION_MAKE
OPTION_NINJA
OPTION_MAKETARGET
OPTION_OTHER_CFLAGS
OPTION_OTHER_CPPFLAGS
OPTION_OTHER_CXXFLAGS
OPTION_OTHER_LDFLAGS
OPTION_PREFIX
OPTION_PROJECT_FILE
OPTION_SCHEMES
OPTION_SDK
OPTION_TARGETS
OPTION_TOOL_PREFERENCES
OPTION_WARNING_CFLAGS"

KNOWN_OPTIONS="${KNOWN_GENERAL_OPTIONS}
${KNOWN_AUTOCONF_PLUGIN_OPTIONS}
${KNOWN_CMAKE_PLUGIN_OPTIONS}
${KNOWN_CONFIGURE_PLUGIN_OPTIONS}
${KNOWN_MESON_PLUGIN_OPTIONS}
${KNOWN_XCODEBUILD_PLUGIN_OPTIONS}"


#
#
all_userdefined_unknown_keys()
{
   log_entry "all_userdefined_unknown_keys" "$@"

   if [ -z "${DEFINED_OPTIONS}" ]
   then
      return
   fi

   local pattern

   pattern="$(tr '\012' '|' <<< "${KNOWN_OPTIONS}")"
   pattern="$(sed 's/\(.*\)|$/\1/g' <<< "${pattern}")"

   log_debug "${DEFINED_OPTIONS}"
   egrep -v -x "${pattern}" <<< "${DEFINED_OPTIONS}"
}


all_userdefined_unknown_plus_keys()
{
   log_entry "all_userdefined_unknown_plus_keys" "$@"

   if [ -z "${DEFINED_PLUS_OPTIONS}" ]
   then
      return
   fi

   local pattern

   pattern="$(tr '\012' '|' <<< "${KNOWN_OPTIONS}")"
   pattern="$(sed 's/\(.*\)|$/\1/g' <<< "${pattern}")"

   log_debug "${DEFINED_PLUS_OPTIONS}"
   egrep -v -x "${pattern}" <<< "${DEFINED_PLUS_OPTIONS}"
}


#
# defined for xcodebuild by default
#
emit_userdefined_definitions()
{
   log_entry "emit_userdefined_definitions" "$@"

   local prefix="$1"
   local sep="${2:-=}"
   local plussep="${3:-=}"
   local pluspref="${4:-\$(inherited) }"

   local key
   local buildsettings
   local value

   IFS="
"
   for key in `all_userdefined_unknown_keys`
   do
      IFS="${DEFAULT_IFS}"
      value="`eval echo "\\\$$key"`"
      buildsettings="`concat "${buildsetting}" "${prefix}${key#OPTION_}${sep}'${value}'"`"
   done

   #
   # emit plus definitions if they are distinguishable
   #
   if [ "${plussep}" != "${sep}" -o ! -z "${pluspref}" ]
   then
      IFS="
"
      for key in `all_userdefined_unknown_plus_keys`
      do
         IFS="${DEFAULT_IFS}"
         value="`eval echo "\\\$$key"`"
         buildsettings="`concat "${buildsetting}" "${prefix}${key#OPTION_}${plussep}'${pluspref}${value}'"`"
      done
   fi
   IFS="${DEFAULT_IFS}"

   printf "%s" "${buildsettings}"
}


#
# this defines a non-exported variable with prefix
# OPTION_
#
check_option_key_without_prefix()
{
   log_entry "check_option_key_without_prefix" "$@"

   local key="$1"

   case "${key}" in
      OPTION_*)
         fail "Key \"${key}\" must not have OPTION_ prefix"
      ;;
   esac

   local match

   if ! fgrep -q -s -x "OPTION_${key}" <<< "${KNOWN_OPTIONS}"
   then
      local message
      local hint

      message="\"${key}\" is not a known option"

      case "${key}" in
         OPTION_*)
            hint="\n(Hint: Do not specify the OPTION_ prefix yourself)"
         ;;
      esac

      message="\"${key}\" is not a known option"
      if [ "${OPTION_ALLOW_UNKNOWN_OPTION}" != "NO" ]
      then
         log_fluff "${message}. Maybe OK, especially with xcode."
      else
         fail "${message}${hint}"
      fi
   fi

   if LC_ALL=C fgrep -q -s -x "OPTION_${key}" <<< "${DEFINED_OPTIONS}" ||
      LC_ALL=C fgrep -q -s -x "OPTION_${key}" <<< "${DEFINED_PLUS_OPTIONS}"
   then
      fail "OPTION \"${key}\" has already been defined"
   fi
}


make_define_option()
{
   log_entry "make_define_option" "$@"

   local key="$1"
   local value="$2"

   check_option_key_without_prefix "${key}"

   eval "OPTION_${key}='${value}'"

   log_fluff "OPTION_${key} defined as \"${value}\""

   DEFINED_OPTIONS="`add_line "${DEFINED_OPTIONS}" "OPTION_${key}"`"
}


make_define_plusoption()
{
   log_entry "make_define_plusoption" "$@"

   local key="$1"
   local value="$2"

   check_option_key_without_prefix "${key}"

   eval "OPTION_${key}='${value}'"

   log_fluff "OPTION_${key} defined as \"${value}\""

   DEFINED_PLUS_OPTIONS="`add_line "${DEFINED_PLUS_OPTIONS}" "OPTION_${key}"`"
}



make_define_option_keyvalue()
{
   log_entry "make_define_option_keyvalue" "$@"

   local keyvalue="$1"

   if [ -z "${keyvalue}" ]
   then
      fail "Missing key, directly after -D"
      make_usage
   fi

   local key
   local value

   key="`echo "${keyvalue}" | cut -d= -f1 | tr 'a-z' 'A-Z'`"
   if [ -z "${key}" ]
   then
      key="${keyvalue}"
   else
      value="`echo "${keyvalue}" | cut -d= -f2-`"
   fi

   make_define_option "${key}" "${value}"
}


make_define_plusoption_keyvalue()
{
   log_entry "make_define_plusoption_keyvalue" "$@"

   local keyvalue="$1"

   if [ -z "${keyvalue}" ]
   then
      fail "Missing key, directly after -D"
      make_usage
   fi

   local key
   local value

   key="`echo "${keyvalue}" | cut '-d+' -f1 | tr 'a-z' 'A-Z'`"
   if [ -z "${key}" ]
   then
      key="${keyvalue}"
   else
      value="`echo "${keyvalue}" | cut '-d=' -f2-`"
   fi

   make_define_plusoption "${key}" "${value}"
}



read_defines_dir()
{
   log_entry "read_defines_dir" "$@"

   local directory="$1"
   local callback="$2"

   local key
   local value
   local filename

   IFS="
"
   for filename in `ls -1 "${directory}"/[A-Z_][A-Z0-9_]* 2> /dev/null`
   do
      IFS="${DEFAULT_IFS}"

      value="`egrep -v '^#' "${filename}"`"
      if [ -z "${value}" ]
      then
         continue
      fi

      # case insensitive fs needs this
      key="`basename -- "${filename}"`"
      key="$(tr '[a-z]' '[A-Z]' <<< "${key}")"

      "${callback}" "${key}" "${value}"
   done

   IFS="${DEFAULT_IFS}"
}


#
# it is assumed that the caller (mulle-craft) resolved the UNAME already
#
read_info_dir()
{
   log_entry "read_info_dir" "$@"

   local infodir="$1"

   [ -z "${infodir}" ] && return

   if [ ! -e "${infodir}" ]
   then
      log_verbose "There is no \"${infodir}\" ($PWD)"
      return
   fi

   if [ ! -d "${infodir}" ]  # now required
   then
      fail "Infodir \"${infodir}\" must be a directory ($PWD)"
   fi

   read_defines_dir "${infodir}" "make_define_option"
   read_defines_dir "${infodir}/plus" "make_define_plus_option"
}


_make_build_main()
{
   log_entry "_make_build_main" "$@"

   local cmd="${1:-build}"
   shift

   [ -z "${DEFAULT_IFS}" ] && internal_fail "IFS fail"

   local OPTION_TOOL_PREFERENCES="cmake
meson
autoconf
configure"
   case "${UNAME}" in
      darwin)
         OPTION_TOOL_PREFERENCES="${OPTION_TOOL_PREFERENCES}
xcodebuild"
      ;;
   esac

   local OPTION_ALLOW_UNKNOWN_OPTION="DEFAULT"
   local OPTION_CLEAN_BEFORE_BUILD="DEFAULT"
   local OPTION_CONFIGURATION="DEFAULT"
   local OPTION_DETERMINE_XCODE_SDK="DEFAULT"
   local OPTION_SDK="DEFAULT"
   local OPTION_NINJA="DEFAULT"

   local OPTION_BUILD_DIR
   local OPTION_INFO_DIR
   local OPTION_LOG_DIR
   local OPTION_PREFIX

   local argument

   while read -r argument
   do
      case "${argument}" in
         -h*|--help|help)
            "${usage}"
         ;;

         --allow-unknown-option)
            OPTION_ALLOW_UNKNOWN_OPTION="YES"
         ;;

         --no-allow-unknown-option)
            OPTION_ALLOW_UNKNOWN_OPTION="NO"
         ;;

         --debug)
            OPTION_CONFIGURATION="Debug"
         ;;

         --release)
            OPTION_CONFIGURATION="Release"
         ;;

         --ninja)
            OPTION_NINJA="YES"
         ;;

         --no-ninja)
            OPTION_NINJA="NO"
         ;;

         --determine-xcode-sdk)
            OPTION_DETERMINE_XCODE_SDK="YES"
         ;;

         --no-determine-xcode-sdk)
            OPTION_DETERMINE_XCODE_SDK="NO"
         ;;

         -n|--name|--project-name)
            read -r OPTION_PROJECT_NAME || fail "missing argument to \"${argument}\""
         ;;

         --tools|--tool-preferences)
            read -r argument || fail "missing argument to \"${argument}\""

            # convenient to allow empty parameter here (for mulle-bootstrap)
            if [ ! -z "${argument}" ]
            then
               OPTION_TOOL_PREFERENCES="`printf "%s" "${argument}" | tr ',' '\012'`"
            fi
         ;;

         --xcode-config-file)
            read -r OPTION_XCODE_XCCONFIG_FILE || fail "missing argument to \"${argument}\""
         ;;

         #
         # with shortcuts
         #
         -b|--build-dir)
            read -r OPTION_BUILD_DIR || fail "missing argument to \"${argument}\""
         ;;

         -c|--configuration)
            read -r OPTION_CONFIGURATION || fail "missing argument to \"${argument}\""
         ;;

         -i|--info-dir)
            read -r OPTION_INFO_DIR || fail "missing argument to \"${argument}\""
         ;;

         -j|--cores)
            read -r OPTION_CORES || fail "missing argument to \"${argument}\""

            case "${UNAME}" in
               mingw)
                   "${usage}"
               ;;
            esac
         ;;

         -k|--clean)
            OPTION_CLEAN_BEFORE_BUILD="YES"
         ;;

         -K|--no-clean)
            OPTION_CLEAN_BEFORE_BUILD="NO"
         ;;

         -l|--log-dir)
            read -r OPTION_LOG_DIR || fail "missing argument to \"${argument}\""
         ;;

         -p|--prefix)
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

         -D*+=*)
            make_define_plusoption_keyvalue "`echo "${argument}" | sed s'/^-D[ ]*//'`"
         ;;

         -D*)
            make_define_option_keyvalue "`echo "${argument}" | sed s'/^-D[ ]*//'`"
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
         -L|--lib-path)
            read -r OPTION_LIB_PATH || fail "missing argument to \"${argument}\""
         ;;

         -V|--verbose-make)
            MULLE_FLAG_VERBOSE_MAKE="YES"
         ;;

         -*)
            log_error "Unknown build option ${argument}"
            "${usage}"
         ;;

         ""|*)
            break
         ;;
      esac
   done

   if [ -z "${MULLE_MAKE_COMMON_SH}" ]
   then
      . "${MULLE_MAKE_LIBEXEC_DIR}/mulle-make-common.sh" || return 1
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

   local srcdir
   local dstdir

   case "${cmd}" in
      build)
         srcdir="${argument:-$PWD}"
         if read -r argument
         then
            log_error "Superflous argument \"${argument}\""
            build_usage
         fi

         if [ ! -d "${srcdir}" ]
         then
            fail "Source directory \"${srcdir}\" is missing"
         fi

         local infodir

         infodir="${OPTION_INFO_DIR}"
         read_info_dir "${infodir}"

         build "${cmd}" "${srcdir}"
      ;;

      install)
         srcdir="${argument}"
         if ! read -r dstdir
         then
            log_fluff "Defaulting to install prefix \"/tmp\", as there is no argument"
            dstdir="/tmp"
         fi

         if read -r argument
         then
            log_error "Superflous argument \"${argument}\""
            install_usage
         fi

         if [ ! -d "${srcdir}" ]
         then
            fail "Source directory \"${srcdir}\" is missing"
         fi

         local infodir

         infodir="${OPTION_INFO_DIR}"
         read_info_dir "${infodir}"

         build "install" "${srcdir}" "${dstdir}"
      ;;
   esac
}


make_build_main()
{
   log_entry "make_build_main" "$@"

   usage="build_usage"
   _make_build_main "build" "$@"
}


make_install_main()
{
   log_entry "make_install_main" "$@"

   usage="install_usage"
   _make_build_main "install" "$@"
}

