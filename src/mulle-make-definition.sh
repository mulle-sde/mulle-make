#! /usr/bin/env bash
#
#   Copyright (c) 2018 Nat! - Mulle kybernetiK
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
MULLE_MAKE_DEFINITION_SH="included"


make_definition_usage()
{
   [ $# -ne 0 ] && log_error "$1"

   cat <<EOF >&2
Usage:
   ${MULLE_USAGE_NAME} ${MULLE_USAGE_COMMAND:-definition} [option] <command>

   Examine and change build settings.

Commands:
   get   :  get a specific value
   list  :  list values
   set   :  set a specific value

Options:
   --info-dir <path>  : specify info directory to edit (.mulle-make)
EOF
   exit 1
}


make_definition_list_usage()
{
   [ $# -ne 0 ] && log_error "$1"

   cat <<EOF >&2
Usage:
   ${MULLE_USAGE_NAME} ${MULLE_USAGE_COMMAND:-definition} list

   List build settings.
EOF
   exit 1
}


make_definition_get_usage()
{
   [ $# -ne 0 ] && log_error "$1"

   cat <<EOF >&2
Usage:
   ${MULLE_USAGE_NAME} ${MULLE_USAGE_COMMAND:-definition} get <key>

   Retrieve a build setting by name.
EOF
   exit 1
}


make_definition_set_usage()
{
   [ $# -ne 0 ] && log_error "$1"

   cat <<EOF >&2
Usage:
   ${MULLE_USAGE_NAME} ${MULLE_USAGE_COMMAND:-definition} set [option] <key> <value>

   Set a build setting. There are two different types of build settings.
   Additive and non-additive. Use non-additive for settings like CC. Use
   additive for settings like compiler flags.

Options:
   -+|--additive : create an additive setting (+=)

EOF
   exit 1
}


#
#
#
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
OPTION_DETERMINE_SDK
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
emit_definitions()
{
   log_entry "emit_definitions" "$@"

   local keys="$1"
   local pluskeys="$2"

   local prefix="$3"
   local sep="$4"
   local plussep="$5"
   local pluspref="$6"
   local concatsep="$7"

   local s
   local key
   local value

   IFS="
"
   for key in ${keys}
   do
      IFS="${DEFAULT_IFS}"

      value="`eval echo "\\\$$key"`"
      s="`concat "${s}" "${prefix}${key#OPTION_}${sep}'${value}'" "${concatsep}"`"
   done
   IFS="${DEFAULT_IFS}"

   #
   # emit plus definitions if they are distinguishable
   #
   IFS="
"
   for key in ${pluskeys}
   do
      IFS="${DEFAULT_IFS}"

      value="`eval echo "\\\$$key"`"
      s="`concat "${s}" "${prefix}${key#OPTION_}${plussep}'${pluspref}${value}'"`"
   done
   IFS="${DEFAULT_IFS}"

   printf "%s" "${s}"
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

   if [ "${pluspref}" = "-" ]
   then
      pluspref=""
   fi

   keys=`all_userdefined_unknown_keys`

   #
   # emit plus definitions if they are distinguishable
   #
   if [ "${plussep}" != "${sep}" -o ! -z "${pluspref}" ]
   then
      pluskeys="`all_userdefined_unknown_plus_keys`"
   fi

   emit_definitions "${keys}" "${pluskeys}" \
                     "${prefix}" "${sep}" "${plussep}" "${pluspref}" " "
}


check_option_key_without_prefix()
{
   log_entry "check_option_key_without_prefix" "$@"

   local key="$1"
   local userkey="${2:-$1}"

   case "${key}" in
      "")
         fail "Empty key"
      ;;

      OPTION_*)
         fail "Key \"${userkey}\" must not have OPTION_ prefix"
      ;;
   esac

   local identifier

   identifier="`printf "%s" "${key}" | tr -c 'a-zA-Z0-9' '_' | tr 'a-z' 'A-Z'`"
   if [ "${key}" != "${identifier}" ]
   then
      fail "\"${userkey}\" is not a proper upcase identifier. Suggestion: \"${identifier}\""
   fi

   local match

   if ! fgrep -q -s -x "OPTION_${key}" <<< "${KNOWN_OPTIONS}"
   then
      local message
      local hint

      case "${key}" in
         OPTION_*)
            hint="\n(Hint: Do not specify the OPTION_ prefix yourself)"
         ;;
      esac

      message="\"${userkey}\" is not a known option"
      if [ "${OPTION_ALLOW_UNKNOWN_OPTION}" != "NO" ]
      then
         log_fluff "${message}. Maybe OK, especially with cmake and xcode."
      else
         fail "${message}${hint}"
      fi
   fi

   if LC_ALL="C" fgrep -q -s -x "OPTION_${key}" <<< "${DEFINED_OPTIONS}" ||
      LC_ALL="C" fgrep -q -s -x "OPTION_${key}" <<< "${DEFINED_PLUS_OPTIONS}"
   then
      log_warning "\"${key}\" has already been defined"
   fi
}


#
# this defines a non-exported variable with prefix
# OPTION_
#
make_define_option()
{
   log_entry "make_define_option" "$@"

   local key="$1"
   local value="$2"
   local userkey="$3"

   check_option_key_without_prefix "${key}" "${userkey}"

   local escaped

   escaped="`escaped_doublequotes "${value}"`"
   eval "OPTION_${key}=\"${escaped}\""

   log_fluff "OPTION_${key} defined as \"${value}\""

   DEFINED_OPTIONS="`add_line "${DEFINED_OPTIONS}" "OPTION_${key}"`"
}


make_define_plusoption()
{
   log_entry "make_define_plusoption" "$@"

   local key="$1"
   local value="$2"
   local userkey="$3"

   check_option_key_without_prefix "${key}" "${userkey}"

   local escaped

   escaped="`escaped_doublequotes "${value}"`"
   eval "OPTION_${key}=\"${escaped}\""

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
   fi

   local key
   local value

   key="`echo "${keyvalue}" | cut -d= -f1`"
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
   fi

   local key
   local value

   key="`echo "${keyvalue}" | cut '-d+' -f1`"
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

   shopt -s nullglob
   for filename in "${directory}"/[A-Z_][A-Z0-9_]*
   do
      shopt -u nullglob

      if [ ! -f "${filename}" ]
      then
         continue
      fi

      value="`egrep -v '^#' "${filename}"`"
#      if [ -z "${value}" ]
#      then
#         continue
#      fi

      key="`basename -- "${filename}"`"

      # ignore files with an extension
      case "${key}" in
         *.*)
            continue
         ;;
      esac

      # case insensitive fs need this
      key="$(tr '[a-z]' '[A-Z]' <<< "${key}")"

      "${callback}" "$(tr '[a-z]' '[A-Z]' <<< "${key}")" "${value}" "${key}"
   done
   shopt -u nullglob
}


#
# it is assumed that the caller (mulle-craft) resolved the UNAME already
#
read_info_dir()
{
   log_entry "read_info_dir" "$@"

   local infodir="$1"

   [ "${infodir}" = "NONE" ] && return

   if [ ! -d "${infodir}" ]
   then
      if [ ! -z "${infodir}" ]
      then
         log_verbose "There is no \"${infodir}\" here ($PWD)"
      fi
      return
   fi

   infodir="${infodir}"

   read_defines_dir "${infodir}/set"  "make_define_option"
   read_defines_dir "${infodir}/plus" "make_define_plusoption"
}

#
# Commands
#

set_info_dir()
{
   log_entry "set_info_dir" "$@"

   local info_dir="$1"

   log_entry "get_info_dir" "$@"

   local info_dir="$1"

   local argument
   local OPTION_ADDITIVE="NO"

   while read -r argument
   do
      case "${argument}" in
         -h*|--help|help)
            make_definition_set_usage
         ;;

         -+|--additive)
            OPTION_ADDITIVE="YES"
         ;;

         -*)
            make_definition_set_usage "unknown option \"${argument}\""
         ;;

         *)
            break
         ;;
      esac
   done

   local key
   local value

   if [ -z "${argument}" ]
   then
      make_definition_set_usage "Missing key"
   fi
   key="${argument}"

   if ! read -r argument
   then
      make_definition_set_usage "Missing value"
   fi
   value="${argument}"

   if read -r argument
   then
      make_definition_set_usage "Superflous argument \"${argument}\""
   fi

   read_info_dir "${info_dir}"

   check_option_key_without_prefix "${key}"

   if [ "${OPTION_ADDITIVE}" = "YES" ]
   then
      info_dir="${info_dir}/plus"
   else
      info_dir="${info_dir}/set"
   fi

   mkdir_if_missing "${info_dir}"
   redirect_exekutor "${info_dir}/${key}" echo "${value}"
}


get_info_dir()
{
   log_entry "get_info_dir" "$@"

   local info_dir="$1"

   local argument

   while read -r argument
   do
      case "${argument}" in
         -h*|--help|help)
            make_definition_get_usage
         ;;

         -*)
            make_definition_get_usage "unknown option \"${argument}\""
         ;;

         *)
            break
         ;;
      esac
   done

   local key

   if [ -z "${argument}" ]
   then
      make_definition_get_usage "missing key"
   fi
   key="${argument}"

   if read -r argument
   then
      make_definition_list_usage "superflous argument \"${argument}\""
   fi

   read_info_dir "${info_dir}"

   key="OPTION_${key}"
   eval echo "\\\$$key"
}


list_info_dir()
{
   log_entry "list_info_dir" "$@"

   local info_dir="$1"

   local argument

   while read -r argument
   do
      case "${argument}" in
         -h*|--help|help)
            make_definition_list_usage
         ;;

         -*)
            make_definition_list_usage "unknown option \"${argument}\""
         ;;

         *)
            break
         ;;
      esac
   done

   if [ ! -z "${argument}" ]
   then
      make_definition_list_usage "superflous argument \"${argument}\""
   fi

   read_info_dir "${info_dir}"

   emit_definitions "${DEFINED_OPTIONS}" "${DEFINED_PLUS_OPTIONS}" \
                     "" "=" "+=" "" "" "
"
   echo
}


make_definition_main()
{
   log_entry "make_definition_main" "$@"

   [ -z "${DEFAULT_IFS}" ] && internal_fail "IFS fail"

   local OPTION_ALLOW_UNKNOWN_OPTION="DEFAULT"
   local OPTION_INFO_DIR=".mulle-make"

   local argument

   while read -r argument
   do
      case "${argument}" in
         -h*|--help|help)
            make_definition_usage
         ;;

         --allow-unknown-option)
            OPTION_ALLOW_UNKNOWN_OPTION="YES"
         ;;

         --no-allow-unknown-option)
            OPTION_ALLOW_UNKNOWN_OPTION="NO"
         ;;

         #
         # with shortcuts
         #
         -i|--info-dir)
            read -r OPTION_INFO_DIR || make_definition_usage "missing argument to \"${argument}\""
         ;;

         -*)
            make_definition_usage "Unknown definition option ${argument}"
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

   local cmd="${argument}"

   case "${cmd}" in
      list|get)
         if ! [ -d "${OPTION_INFO_DIR}" ]
         then
            fail "Directory \"${OPTION_INFO_DIR}\" not found"
         fi

         ${cmd}_info_dir "${OPTION_INFO_DIR}"
      ;;

      set)
         set_info_dir "${OPTION_INFO_DIR}"
      ;;

      "")
         make_definition_usage
      ;;

      *)
         make_definition_usage "Unknown command ${cmd}"
      ;;
   esac
}

