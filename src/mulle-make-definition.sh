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

   Examine and change build definitions. A "definition" is a flag passed to the
   buildtool. Specify a set of definitions with a "definition directory".
   These dictionaries are conveniently maintained with this command.

   Definitions maintained this way are persistent and shareable with other users.

   There is also the possiblity of adding definitions on the commandline
   during the build step. These definitions are useful for per-project tweaks,
   that should not affect downstream users.
   (see \`${MULLE_USAGE_NAME} project -h\` for more information).

Commands:
   get   :  get a specific value
   keys  :  list all known builtin keys
   list  :  list defined values
   set   :  set a specific value

Options:
   --definition-dir <path>  : specify info directory to edit (.mulle-make)
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

   Retrieve a build setting by name. Will echo to standard output.

Returns:
   0 : found
   1 : error
   2 : not found
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
# grep through project to get the options:_
# egrep -h -o -w 'OPTION_[A-Z0-9_]*[A-Z0-9]' src/*.sh src/plugins/*.sh | LC_ALL=C sort -u
#
KNOWN_AUTOCONF_PLUGIN_OPTIONS="\
OPTION_AUTOCONF
OPTION_AUTORECONF
OPTION_AUTOCONFFLAGS
OPTION_AUTORECONFFLAGS"

KNOWN_CMAKE_PLUGIN_OPTIONS="\
OPTION_CMAKE
OPTION_CMAKE_BUILD_TYPE
OPTION_CMAKE_C_FLAGS
OPTION_CMAKE_CXX_FLAGS
OPTION_CMAKE_C_COMPILER
OPTION_CMAKE_CXX_COMPILER
OPTION_CMAKE_LINKER
OPTION_CMAKE_SHARED_LINKER_FLAGS
OPTION_CMAKE_EXE_LINKER_FLAGS
OPTION_CMAKE_INCLUDE_PATH
OPTION_CMAKE_LIBRARY_PATH
OPTION_CMAKE_FRAMEWORK_PATH
OPTION_CMAKE_INSTALL_PREFIX
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
OPTION_BUILD_SCRIPT
OPTION_CC
OPTION_CFLAGS
OPTION_CLEAN_BEFORE_BUILD
OPTION_CONFIGURATION
OPTION_CPPFLAGS
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
OPTION_PROJECT_LANGUAGE
OPTION_PROJECT_NAME
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


is_plus_key()
{
   log_entry "is_plus_key" "$@"

   fgrep -q -F -x "$1" <<< "${DEFINED_PLUS_OPTIONS}"
}


#
# defined for xcodebuild by default
#
r_print_definitions()
{
   log_entry "r_print_definitions" "$@"

   local keys="$1"      # list of -DFOO=XX keys separated by linefeed
   local pluskeys="$2"  # list of -DFOO+=XX keys separated by linefeed

   local prefix="$3"    # prefix to prepend to key
   local sep="$4"
   local plussep="$5"
   local pluspref="$6"
   local quote="$7"
   local concatsep="$8"

   local s
   local key
   local value

   IFS="
"
   for key in ${keys}
   do
      IFS="${DEFAULT_IFS}"

      value="`eval echo "\\\$$key"`"
      r_concat "${s}" "${prefix}${key#OPTION_}${sep}${quote}${value}${quote}" "${concatsep}"
      s="${RVAL}"
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
      r_concat "${s}" "${prefix}${key#OPTION_}${plussep}${quote}${pluspref}${value}${quote}" "${concatsep}"
      s="${RVAL}"
   done
   IFS="${DEFAULT_IFS}"

   RVAL="$s"

   log_debug "User definition: ${s}"
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

   #
   # only emit UNKNOWN keys, the known keys are handled
   # by the plugins themselves
   #
   keys=`all_userdefined_unknown_keys`

   #
   # emit plus definitions if they are distinguishable
   #
   if [ "${plussep}" != "${sep}" -o ! -z "${pluspref}" ]
   then
      pluskeys="`all_userdefined_unknown_plus_keys`"
   fi

   r_print_definitions "${keys}" "${pluskeys}" \
                       "${prefix}" "${sep}" "${plussep}" "${pluspref}" "\'" " "
   [ ! -z "${RVAL}" ] && echo "${RVAL}"
}


check_option_key_without_prefix()
{
   log_entry "check_option_key_without_prefix" "$@"

   local key="$1"

   case "${key}" in
      "")
         fail "Empty key"
      ;;

      OPTION_*)
         fail "Key \"${key}\" must not have OPTION_ prefix"
      ;;
   esac

   local identifier

   identifier="`printf "%s" "${key}" | tr -c 'a-zA-Z0-9' '_' | tr 'a-z' 'A-Z'`"
   if [ "${key}" != "${identifier}" ]
   then
      fail "\"${key}\" is not a proper upcase identifier. Suggestion: \"${identifier}\""
   fi

   local match
   local escaped

   if ! fgrep -q -s -x "OPTION_${key}" <<< "${KNOWN_OPTIONS}"
   then
      local message
      local hint

      case "${key}" in
         OPTION_*)
            hint="\n(Hint: Do not specify the OPTION_ prefix yourself)"
         ;;
      esac

      message="\"${key}\" is not a known option"
      if [ "${OPTION_ALLOW_UNKNOWN_OPTION}" != "NO" ]
      then
         log_fluff "${message}. Maybe OK, especially with cmake and xcode."
      else
         fail "${message}${hint}"
      fi
   fi
}


check_key_without_prefix_exists()
{
   log_entry "check_key_without_prefix_exists" "$@"

   local key="$1"
   local option="$2"

   if [ -z "${option}" ]
   then
      if LC_ALL="C" fgrep -q -s -x "OPTION_${key}" <<< "${DEFINED_OPTIONS}" ||
         LC_ALL="C" fgrep -q -s -x "OPTION_${key}" <<< "${DEFINED_PLUS_OPTIONS}"
      then
         log_warning "\"${key}\" has already been defined"
      fi
   fi
}


#
# this defines a non-exported variable with prefix
# OPTION_
#
_make_define_option()
{
   log_entry "_make_define_option" "$@"

   local key="$1"
   local value="$2"
   local option="$3"

   check_option_key_without_prefix "${key}"
   check_key_without_prefix_exists "${key}" "${option}"

   local oldvalue
   local escaped
   local RVAL

   if [ ! -z "${option}" ]
   then
      oldvalue="`eval echo "\\\$OPTION_$key"`"
      case "${option}" in
         'ifempty')
            if [ ! -z "${oldvalue}" ]
            then
               log_debug "Skip as ${key} is already defined as \"${oldvalue}"
               return 1
            fi
         ;;

         'remove')
            if [ -z "${oldvalue}" ]
            then
               log_debug "${key} is already empty"
               return 1
            fi

            r_escaped_sed_pattern "${value}"
            value="`sed "s/${RVAL}//g" <<< "${oldvalue}"`"

            if [ "${value}" = "${oldvalue}" ]
            then
               log_debug "Remove did not remove anything"
            fi
         ;;

         'append')
            r_concat "${oldvalue}" "${value}"
            value="${RVAL}"
         ;;

         'append0')
            value="${oldvalue}${value}"
         ;;
      esac
   fi

   r_escaped_doublequotes "${value}"
   escaped="${RVAL}"
   eval "OPTION_${key}=\"${escaped}\""

   log_fluff "OPTION_${key} defined as \"${value}\""
}



make_undefine_option()
{
   log_entry "make_undefine_option" "$@"

   local key="$1"

   unset "OPTION_${key}"

   DEFINED_OPTIONS="`fgrep -v -x "OPTION_${key}" <<< "${DEFINED_OPTIONS}" `"
   DEFINED_PLUS_OPTIONS="`fgrep -v -x "OPTION_${key}" <<< "${DEFINED_PLUS_OPTIONS}" `"
}



make_define_option()
{
   log_entry "make_define_option" "$@"

   local key="$1"

   local RVAL

   if ! _make_define_option "$@"
   then
      return 1
   fi

   # ensure append doesn't duplicate
   case "${DEFINED_OPTIONS}" in
      "OPTION_${key}")
         DEFINED_OPTIONS="`fgrep -v -x "OPTION_${key}" <<< "${DEFINED_OPTIONS}" `"
      ;;
   esac

   r_add_line "${DEFINED_OPTIONS}" "OPTION_${key}"
   DEFINED_OPTIONS="${RVAL}"
}


make_define_plusoption()
{
   log_entry "make_define_plusoption" "$@"

   local key="$1"

   if ! _make_define_option "$@"
   then
      return 1
   fi

   # ensure append doesn't duplicate
   case "${DEFINED_PLUS_OPTIONS}" in
      "OPTION_${key}")
         DEFINED_PLUS_OPTIONS="`fgrep -v -x "OPTION_${key}" <<< "${DEFINED_PLUS_OPTIONS}" `"
      ;;
   esac

   r_add_line "${DEFINED_PLUS_OPTIONS}" "OPTION_${key}"
   DEFINED_PLUS_OPTIONS="${RVAL}"
}


make_define_option_keyvalue()
{
   log_entry "make_define_option_keyvalue" "$@"

   local keyvalue="$1"
   local option="$2"

   if [ -z "${keyvalue}" ]
   then
      fail "Missing key, directly after -D"
   fi

   local key
   local value

   key="${keyvalue%%=*}"
   if [ "${key}" != "${keyvalue}" ]
   then
      value="${keyvalue#*=}"
   fi
   make_define_option "${key}" "${value}" "${option}"
}


make_define_plusoption_keyvalue()
{
   log_entry "make_define_plusoption_keyvalue" "$@"

   local keyvalue="$1"
   local option="$2"

   if [ -z "${keyvalue}" ]
   then
      fail "Missing key, directly after -D"
   fi

   local key
   local value

   key="${keyvalue%%+=*}"
   if [ "${key}" != "${keyvalue}" ]
   then
      value="${keyvalue#*+=}"
   fi

   make_define_plusoption "${key}" "${value}" "${option}"
}


read_defines_dir()
{
   log_entry "read_defines_dir" "$@"

   local directory="$1"
   local callback="$2"
   local option="$3"

   local key
   local value
   local filename

   log_fluff "Searching in \"${directory}\" for definitions (${option})"

   shopt -s nullglob
   for filename in "${directory}"/[A-Z_][A-Z0-9_]*
   do
      shopt -u nullglob

      r_fast_basename "${filename}"
      key="${RVAL}"

      # ignore files with an extension
      case "${key}" in
         *"."*)
            continue
         ;;
      esac

      if [ ! -f "${filename}" ]
      then
         continue
      fi

      # case insensitive fs need this
      key="$(tr '[a-z]' '[A-Z]' <<< "${key}")"

      value="`egrep -v '^#' "${filename}"`"
#      if [ -z "${value}" ]
#      then
#         continue
#      fi

      "${callback}" "${key}" "${value}" "${option}"
   done
   shopt -u nullglob
}


#
# it is assumed that the caller (mulle-craft) resolved the UNAME already
#
read_definition_dir()
{
   log_entry "read_definition_dir" "$@"

   local directory="$1"

   [ "${directory}" = "NONE" ] && return

   if [ ! -d "${directory}" ]
   then
      if [ ! -z "${directory}" ]
      then
         log_fluff "There is no \"${directory}\" here ($PWD)"
      fi
      return
   fi

   log_verbose "Read info ${C_RESET_BOLD}${directory}${C_VERBOSE}"

   directory="${directory}"

   read_defines_dir "${directory}/set/remove"   "make_define_option" "remove"
   read_defines_dir "${directory}/set/ifempty"  "make_define_option" "ifempty"
   read_defines_dir "${directory}/set/append"   "make_define_option" "append"
   read_defines_dir "${directory}/set/append0"  "make_define_option" "append0"
   read_defines_dir "${directory}/set"          "make_define_option"

   read_defines_dir "${directory}/plus/remove"  "make_define_plusoption" "remove"
   read_defines_dir "${directory}/plus/ifempty" "make_define_plusoption" "ifempty"
   read_defines_dir "${directory}/plus/append"  "make_define_plusoption" "append"
   read_defines_dir "${directory}/plus/append0" "make_define_plusoption" "append0"
   read_defines_dir "${directory}/plus"         "make_define_plusoption"
}


remove_other_keyfiles_than()
{
   log_entry "remove_other_keyfiles_than" "$@"

   local keyfile="$1" ; shift

   local otherfile

   while [ $# -ne 0 ]
   do
      otherfile="$1" ; shift

      if [ "${otherfile}" = "${keyfile}" ]
      then
         continue
      fi

      remove_file_if_present "${otherfile}"
   done
}


#
# Commands
#

set_definition_dir()
{
   log_entry "set_definition_dir" "$@"

   local directory="$1"

   local argument
   local OPTION_ADDITIVE="NO"
   local OPTION_MODIFIER=

   while read -r argument
   do
      case "${argument}" in
         -h*|--help|help)
            make_definition_set_usage
         ;;

         -+|--additive)
            OPTION_ADDITIVE="YES"
         ;;

         --append|--append0|--ifempty|--remove)
            OPTION_MODIFIER="${argument:2}"
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

   read_definition_dir "${directory}"

   check_option_key_without_prefix "${key}"


   local finaldirectory

   if [ "${OPTION_ADDITIVE}" = "YES" ]
   then
      finaldirectory="${directory}/plus"
   else
      finaldirectory="${directory}/set"
   fi

   r_filepath_concat "${directory}" "${OPTION_MODIFIER}"
   finaldirectory="${RVAL}"

   # remove all possible old settings
   remove_other_keyfiles_than "${finaldirectory}/${key}" \
                              "${directory}/set/${key}" \
                              "${directory}/set/append/${key}" \
                              "${directory}/set/append0/${key}" \
                              "${directory}/set/ifempty/${key}"\
                              "${directory}/set/remove/${key}"  \
                              "${directory}/plus/${key}"\
                              "${directory}/plus/append/${key}"\
                              "${directory}/plus/append0/${key}"\
                              "${directory}/plus/ifempty/${key}"\
                              "${directory}/plus/remove/${key}"


   mkdir_if_missing "${finaldirectory}"
   redirect_exekutor "${finaldirectory}/${key}" echo "${value}"
}


get_definition_dir()
{
   log_entry "get_definition_dir" "$@"

   local directory="$1"

   local argument

   while read -r argument
   do
      case "${argument}" in
         -h*|--help|help)
            make_definition_get_usage
         ;;

         -*)
            make_definition_get_usage "Unknown option \"${argument}\""
         ;;

         *)
            break
         ;;
      esac
   done

   local key

   if [ -z "${argument}" ]
   then
      make_definition_get_usage "Missing key"
   fi
   key="${argument}"

   if read -r argument
   then
      make_definition_list_usage "Superflous argument \"${argument}\""
   fi

   read_definition_dir "${directory}"

   key="OPTION_${key}"
   eval echo "\\\$$key"

   # https://stackoverflow.com/questions/3601515/how-to-check-if-a-variable-is-set-in-bash
   if [ -z ${key+x} ]
   then
      return 2
   fi
}


list_definition_dir()
{
   log_entry "list_definition_dir" "$@"

   local directory="$1"

   local argument

   while read -r argument
   do
      case "${argument}" in
         -h*|--help|help)
            make_definition_list_usage
         ;;

         -*)
            make_definition_list_usage "Unknown option \"${argument}\""
         ;;

         *)
            break
         ;;
      esac
   done

   if [ ! -z "${argument}" ]
   then
      make_definition_list_usage "Superflous argument \"${argument}\""
   fi

   read_definition_dir "${directory}"

   r_print_definitions "${DEFINED_OPTIONS}" "${DEFINED_PLUS_OPTIONS}" \
                     "" "=" "+=" "" "" "\'" "
"
   [ ! -z "${RVAL}" ] && echo "${RVAL}"
}


make_definition_main()
{
   log_entry "make_definition_main" "$@"

   [ -z "${DEFAULT_IFS}" ] && internal_fail "IFS fail"

   local OPTION_ALLOW_UNKNOWN_OPTION="DEFAULT"
   local OPTION_DEFINITION_DIR=".mulle-make"

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
         --definition-dir)
            read -r OPTION_DEFINITION_DIR ||
               make_definition_usage "missing argument to \"${argument}\""
         ;;

         -*)
            make_definition_usage "Unknown definition option ${argument}"
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

   local cmd="${argument}"

   case "${cmd}" in
      list|get)
         if ! [ -d "${OPTION_DEFINITION_DIR}" ]
         then
            log_verbose "Directory \"${OPTION_DEFINITION_DIR}\" not found"
            return 2
         fi

         ${cmd}_definition_dir "${OPTION_DEFINITION_DIR}"
      ;;

      keys)
         sed -e 's/^OPTION_//' <<< "${KNOWN_OPTIONS}" | LC_ALL=C sort -u
      ;;

      set)
         set_definition_dir "${OPTION_DEFINITION_DIR}"
      ;;

      "")
         make_definition_usage
      ;;

      *)
         make_definition_usage "Unknown command ${cmd}"
      ;;
   esac
}

