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
   buildtool. This command maintains a permanent ans shareable set of
   definitions.

   There is also the possibility of adding definitions on a per-command basis
   on the commandline for the "make" command.

Commands:
   get    :  get a specific value
   list   :  list defined values
   unset  :  remove a key from the definitions
   set    :  set a specific value
   show   :  list all known builtin keys (excludes plugin specifics)

Options:
   --definition-dir <path>      : definitions to edit (.mulle/etc/craft/definition)
   --aux-definition-dir <path>  : auxilary definitions to read
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
   Additive and non-additive. An additive setting will be emitted with a +=,
   where as a non-addtive setting will be emitted as ?.
   Previous values of the same key can be either appended to or clobbered.

Example:
   ${MULLE_USAGE_NAME} ${MULLE_USAGE_COMMAND:-definition} set FOO bar
   ${MULLE_USAGE_NAME} ${MULLE_USAGE_COMMAND:-definition} set FOO foo

   will produce -DFOO="bar foo"

Options:
   -+        : create an additive setting += instead of =
   --append  : append the value to an existing value for that key (default)
   --append0 : like append but without space separation
   --clobber : clobber any existing previous value
   --ifempty : only set if no value exists yet

EOF
   exit 1
}


make_definition_unset_usage()
{
   [ $# -ne 0 ] && log_error "$1"

   cat <<EOF >&2
Usage:
   ${MULLE_USAGE_NAME} ${MULLE_USAGE_COMMAND:-definition} unset <key>

   Remove a build setting.

EOF
   exit 1
}



#
# grep through project to get the options:_
# egrep -h -o -w 'DEFINITION_[A-Z0-9_]*[A-Z0-9]' src/*.sh src/plugins/*.sh | LC_ALL=C sort -u
#
KNOWN_AUTOCONF_PLUGIN_DEFINITIONS="\
DEFINITION_AUTOCONF
DEFINITION_AUTORECONF
DEFINITION_AUTOCONFFLAGS
DEFINITION_AUTORECONFFLAGS"

KNOWN_CMAKE_PLUGIN_DEFINITIONS="\
DEFINITION_CMAKE
DEFINITION_CMAKE_BUILD_TYPE
DEFINITION_CMAKE_C_FLAGS
DEFINITION_CMAKE_CXX_FLAGS
DEFINITION_CMAKE_C_COMPILER
DEFINITION_CMAKE_CXX_COMPILER
DEFINITION_CMAKE_LINKER
DEFINITION_CMAKE_SHARED_LINKER_FLAGS
DEFINITION_CMAKE_EXE_LINKER_FLAGS
DEFINITION_CMAKE_INCLUDE_PATH
DEFINITION_CMAKE_LIBRARY_PATH
DEFINITION_CMAKE_FRAMEWORK_PATH
DEFINITION_CMAKE_INSTALL_PREFIX
DEFINITION_CMAKEFLAGS
DEFINITION_CMAKE_GENERATOR"

KNOWN_CONFIGURE_PLUGIN_DEFINITIONS="\
DEFINITION_CONFIGUREFLAGS"

KNOWN_MESON_PLUGIN_DEFINITIONS="\
DEFINITION_MESON
DEFINITION_MESONFLAGS
DEFINITION_MESON_BACKEND"

KNOWN_XCODEBUILD_PLUGIN_DEFINITIONS="\
DEFINITION_XCODEBUILD
DEFINITION_XCODE_XCCONFIG_FILE"

#
# General options are not "blindly" passed as commandline arguments to
# mulle-make but handled separately. F.e. putting DEFINITION_MULLE_SDK_PATH in
# here will effectively remove it from the argument list, which is bad
#
KNOWN_GENERAL_DEFINITIONS="\
DEFINITION_BUILD_DIR
DEFINITION_BUILD_SCRIPT
DEFINITION_CC
DEFINITION_CFLAGS
DEFINITION_CLEAN_BEFORE_BUILD
DEFINITION_CONFIGURATION
DEFINITION_CPPFLAGS
DEFINITION_CXX
DEFINITION_CXXFLAGS
DEFINITION_DETERMINE_SDK
DEFINITION_FRAMEWORKS_PATH
DEFINITION_GCC_PREPROCESSOR_DEFINITIONS
DEFINITION_INCLUDE_PATH
DEFINITION_LDFLAGS
DEFINITION_LIB_PATH
DEFINITION_LOG_DIR
DEFINITION_MAKE
DEFINITION_NINJA
DEFINITION_MAKETARGET
DEFINITION_OTHER_CFLAGS
DEFINITION_OTHER_CPPFLAGS
DEFINITION_OTHER_CXXFLAGS
DEFINITION_OTHER_LDFLAGS
DEFINITION_PLUGIN_PREFERENCES
DEFINITION_PREFIX
DEFINITION_PREFER_XCODEBUILD
DEFINITION_PROJECT_FILE
DEFINITION_PROJECT_LANGUAGE
DEFINITION_PROJECT_NAME
DEFINITION_SCHEMES
DEFINITION_SDK
DEFINITION_TARGETS
DEFINITION_USE_NINJA
DEFINITION_WARNING_CFLAGS"

KNOWN_DEFINITIONS="${KNOWN_GENERAL_DEFINITIONS}
${KNOWN_AUTOCONF_PLUGIN_DEFINITIONS}
${KNOWN_CMAKE_PLUGIN_DEFINITIONS}
${KNOWN_CONFIGURE_PLUGIN_DEFINITIONS}
${KNOWN_MESON_PLUGIN_DEFINITIONS}
${KNOWN_XCODEBUILD_PLUGIN_DEFINITIONS}"


#
#
all_userdefined_unknown_keys()
{
   log_entry "all_userdefined_unknown_keys" "$@"

   if [ -z "${DEFINED_SET_DEFINITIONS}" ]
   then
      return
   fi

   local pattern

   pattern="$(tr '\012' '|' <<< "${KNOWN_DEFINITIONS}")"
   pattern="$(sed 's/\(.*\)|$/\1/g' <<< "${pattern}")"

   log_debug "${DEFINED_SET_DEFINITIONS}"
   egrep -v -x "${pattern}" <<< "${DEFINED_SET_DEFINITIONS}"
}


all_userdefined_unknown_plus_keys()
{
   log_entry "all_userdefined_unknown_plus_keys" "$@"

   if [ -z "${DEFINED_PLUS_DEFINITIONS}" ]
   then
      return
   fi

   local pattern

   pattern="$(tr '\012' '|' <<< "${KNOWN_DEFINITIONS}")"
   pattern="$(sed 's/\(.*\)|$/\1/g' <<< "${pattern}")"

   log_debug "${DEFINED_PLUS_DEFINITIONS}"
   egrep -v -x "${pattern}" <<< "${DEFINED_PLUS_DEFINITIONS}"
}


is_plus_key()
{
   log_entry "is_plus_key" "$@"

   fgrep -q -F -x -e "$1" <<< "${DEFINED_PLUS_DEFINITIONS}"
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

   IFS=$'\n'
   for key in ${keys}
   do
      IFS="${DEFAULT_IFS}"

      if [ ! -z "${ZSH_VERSION}" ]
      then
         value="${(P)key}"
      else
         value="${!key}"
      fi
      r_concat "${s}" "${prefix}${key#DEFINITION_}${sep}${quote}${value}${quote}" "${concatsep}"
      s="${RVAL}"
   done
   IFS="${DEFAULT_IFS}"

   #
   # emit plus definitions if they are distinguishable
   #
   IFS=$'\n'
   for key in ${pluskeys}
   do
      IFS="${DEFAULT_IFS}"

      if [ ! -z "${ZSH_VERSION}" ]
      then
         value="${(P)key}"
      else
         value="${!key}"
      fi
      r_concat "${s}" "${prefix}${key#DEFINITION_}${plussep}${quote}${pluspref}${value}${quote}" "${concatsep}"
      s="${RVAL}"
   done
   IFS="${DEFAULT_IFS}"

   RVAL="$s"

   log_debug "User definition: ${s}"
}


#
# defined for xcodebuild by default (\$(inherited))
#
emit_userdefined_definitions()
{
   log_entry "emit_userdefined_definitions" "$@"

   local prefix="$1"
   local sep="${2:-=}"
   local plussep="${3:-=}"
   local pluspref="${4}"
   local quote="${5}"

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
                       "${prefix}" \
                       "${sep}" \
                       "${plussep}" \
                       "${pluspref}" \
                       "${quote}" \
                       " "
   [ ! -z "${RVAL}" ] && printf "%s\n" "${RVAL}"
}


check_option_key_without_prefix()
{
   log_entry "check_option_key_without_prefix" "$@"

   local key="$1"

   case "${key}" in
      "")
         fail "Empty key"
      ;;

      DEFINITION_*)
         fail "Key \"${key}\" must not have DEFINITION_ prefix"
      ;;
   esac

   local identifier

   r_identifier "${key}"
   identifier="${RVAL}"

   if [ "${key}" != "${identifier}" ]
   then
      fail "\"${key}\" is not a proper upcase identifier. Suggestion: \"${identifier}\""
   fi

   local match
   local escaped

   if ! find_line "${KNOWN_DEFINITIONS}" "DEFINITION_${key}"
   then
      local message
      local hint

      case "${key}" in
         DEFINITION_*)
            hint="\n(Hint: Do not specify the DEFINITION_ prefix yourself)"
         ;;
      esac

      message="\"${key}\" is not a known option"
      if [ "${DEFINITION_ALLOW_UNKNOWN_OPTION}" != 'NO' ]
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
      if find_line "${DEFINED_SET_DEFINITIONS}" "DEFINITION_${key}"  ||
         find_line "${DEFINED_PLUS_DEFINITIONS}" "DEFINITION_${key}"
      then
         return 0
      fi
   fi
   return 1
}


#
# this defines a non-exported variable with prefix
# DEFINITION_
#
_make_define_option()
{
   log_entry "_make_define_option" "$@"

   local key="$1"
   local value="$2"
   local option="$3"

   local mayclobber

   check_option_key_without_prefix "${key}"

   local oldvalue
   local optkey

   optkey="DEFINITION_$key"
   if [ ! -z "${ZSH_VERSION}" ]
   then
      oldvalue="${(P)optkey}"
   else
      oldvalue="${!optkey}"
   fi
   case "${option}" in
      'ifempty')
         if [ ! -z "${oldvalue}" ]
         then
            log_debug "Skip as ${key} is already defined as \"${oldvalue}"
            return 1
         fi
      ;;

      'unset'|'remove')
         if [ -z "${oldvalue}" ]
         then
            log_debug "${key} is already empty"
            return 1
         fi

         r_escaped_sed_pattern "${value}"
         value="`sed "s/${RVAL}//g" <<< "${oldvalue}"`"

         if [ "${value}" = "${oldvalue}" ]
         then
            log_debug "Unset did not do anything"
         fi
      ;;

      'append')
         r_concat "${oldvalue}" "${value}"
         value="${RVAL}"
      ;;

      'append0')
         value="${oldvalue}${value}"
      ;;


      ''|'clobber')
         if check_key_without_prefix_exists "${key}" "${option}" \
            && [ "${oldvalue}" != "${value}" ]
         then
            log_warning "warning: \"${key}\" previously defined as \
\"${oldvalue}\" now redefined as \"${value}\""
         fi
      ;;
   esac

   printf -v "${optkey}" "%s" "${value}"

   log_fluff "${optkey} defined as '${value}'"
}



make_undefine_option()
{
   log_entry "make_undefine_option" "$@"

   local key="$1"

   unset "DEFINITION_${key}"

   DEFINED_SET_DEFINITIONS="`fgrep -v -x -e "DEFINITION_${key}" <<< "${DEFINED_SET_DEFINITIONS}" `"
   DEFINED_PLUS_DEFINITIONS="`fgrep -v -x -e "DEFINITION_${key}" <<< "${DEFINED_PLUS_DEFINITIONS}" `"
}


make_define_option()
{
   log_entry "make_define_option" "$@"

   local key="$1"

   if ! _make_define_option "$@"
   then
      return 1
   fi

   # ensure append doesn't duplicate
   case "${DEFINED_SET_DEFINITIONS}" in
      "DEFINITION_${key}")
         DEFINED_SET_DEFINITIONS="`fgrep -v -x "DEFINITION_${key}" <<< "${DEFINED_SET_DEFINITIONS}" `"
      ;;
   esac

   r_add_line "${DEFINED_SET_DEFINITIONS}" "DEFINITION_${key}"
   DEFINED_SET_DEFINITIONS="${RVAL}"
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
   case "${DEFINED_PLUS_DEFINITIONS}" in
      "DEFINITION_${key}")
         DEFINED_PLUS_DEFINITIONS="`fgrep -v -x "DEFINITION_${key}" <<< "${DEFINED_PLUS_DEFINITIONS}" `"
      ;;
   esac

   r_add_line "${DEFINED_PLUS_DEFINITIONS}" "DEFINITION_${key}"
   DEFINED_PLUS_DEFINITIONS="${RVAL}"
}


make_define_set_keyvalue()
{
   log_entry "make_define_set_keyvalue" "$@"

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


make_define_plus_keyvalue()
{
   log_entry "make_define_plus_keyvalue" "$@"

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
   local read_value
   local filename

   shell_enable_nullglob
   for filename in "${directory}"/[A-Z_][A-Z0-9_]*
   do
      shell_disable_nullglob

      r_basename "${filename}"
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

      # case insensitive fs need this (why ???), maybe for normalization ?
      # unfortunately this conflicts with -DCMAKE_DISABLE_LIBRARY_BZip2=ON
      # r_uppercase "${key}"
      # key="${RVAL}"

      # multiple lines coalesced with space
      read_value="`egrep -v '^#' "${filename}" | tr '\n' ' '`"
      r_trim_whitespace "${read_value}"
      read_value="${RVAL}"
#      if [ -z "${value}" ]
#      then
#         continue
#      fi

      r_expanded_string "${read_value}"
      value="${RVAL}"
      log_debug "Evaluated read value \"${read_value}\" to \"${value}\""

      "${callback}" "${key}" "${value}" "${option}"
   done
   shell_disable_nullglob
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
         log_fluff "There is no \"${directory#${MULLE_USER_PWD}/}\" here (${PWD#${MULLE_USER_PWD}/})"
      fi
      return
   fi

   log_verbose "Read definition ${C_RESET_BOLD}${directory#${MULLE_USER_PWD}/}${C_VERBOSE}"

   directory="${directory}"

   read_defines_dir "${directory}/set/unset"    "make_define_option" "unset"
# old
   read_defines_dir "${directory}/set/remove"   "make_define_option" "remove"
   read_defines_dir "${directory}/set/clobber"  "make_define_option"
   read_defines_dir "${directory}/set/ifempty"  "make_define_option" "ifempty"
   read_defines_dir "${directory}/set/append"   "make_define_option" "append"
   read_defines_dir "${directory}/set/append0"  "make_define_option" "append0"
   read_defines_dir "${directory}/set"          "make_define_option" "append"

   read_defines_dir "${directory}/plus/unset"   "make_define_plusoption" "unset"
# old
   read_defines_dir "${directory}/plus/remove"  "make_define_plusoption" "remove"
   read_defines_dir "${directory}/plus/clobber" "make_define_plusoption"
   read_defines_dir "${directory}/plus/ifempty" "make_define_plusoption" "ifempty"
   read_defines_dir "${directory}/plus/append"  "make_define_plusoption" "append"
   read_defines_dir "${directory}/plus/append0" "make_define_plusoption" "append0"
   read_defines_dir "${directory}/plus"         "make_define_plusoption" "append"
}


remove_other_keyfiles_than()
{
   log_entry "remove_other_keyfiles_than" "$@"

   local keyfile="$1" ; shift # empty is ok

   local otherfile
   while [ $# -ne 0 ]
   do
      otherfile="$1" ; shift

      if [ "${otherfile}" = "${keyfile}" ]
      then
         continue
      fi

      remove_file_if_present "${otherfile}"
      r_dirname "${otherfile}"
      rmdir_if_empty "${RVAL}"
   done
}


#
# Commands
#

unset_definition_dir()
{
   log_entry "unset_definition_dir" "$@"

   local directory="$1"

   local argument

	while read -r argument
   do
      case "${argument}" in
         -h*|--help|help)
            make_definition_remove_usage
         ;;

	      -*)
            make_definition_remove_usage "unknown option \"${argument}\""
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
      make_definition_unset_usage "Missing key"
   fi
   key="${argument}"

   if read -r argument
   then
      make_definition_unset_usage "Superflous argument \"${argument}\""
   fi

   # remove all possible old settings
   remove_other_keyfiles_than "" \
                              "${directory}/set/${key}"          \
                              "${directory}/set/append/${key}"   \
                              "${directory}/set/append0/${key}"  \
                              "${directory}/set/ifempty/${key}"  \
                              "${directory}/set/clobber/${key}"  \
                              "${directory}/set/remove/${key}"   \
                              "${directory}/set/unset/${key}"    \
                              "${directory}/plus/${key}"         \
                              "${directory}/plus/append/${key}"  \
                              "${directory}/plus/append0/${key}" \
                              "${directory}/plus/ifempty/${key}" \
                              "${directory}/plus/clobber/${key}" \
                              "${directory}/plus/remove/${key}"  \
                              "${directory}/plus/unset/${key}"

   rmdir_if_empty "${directory}/plus"
   rmdir_if_empty "${directory}/set"
   rmdir_if_empty "${directory}"
}


set_definition_dir()
{
   log_entry "set_definition_dir" "$@"

   local directory="$1"

   local argument
   local OPTION_MODIFIER='set'

   while read -r argument
   do
      case "${argument}" in
         -h*|--help|help)
            make_definition_set_usage
         ;;

         -+|--additive)
            OPTION_MODIFIER='plus'
         ;;

         --append|--append0|--ifempty|--remove|--unset|--clobber)
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

   r_filepath_concat "${directory}" "${OPTION_MODIFIER}"
   finaldirectory="${RVAL}"

   # remove all possible old settings
   remove_other_keyfiles_than "${finaldirectory}/${key}"         \
                              "${directory}/set/${key}"          \
                              "${directory}/set/append/${key}"   \
                              "${directory}/set/append0/${key}"  \
                              "${directory}/set/ifempty/${key}"  \
                              "${directory}/set/clobber/${key}"  \
                              "${directory}/set/remove/${key}"   \
                              "${directory}/set/unset/${key}"    \
                              "${directory}/plus/${key}"         \
                              "${directory}/plus/append/${key}"  \
                              "${directory}/plus/append0/${key}" \
                              "${directory}/plus/ifempty/${key}" \
                              "${directory}/plus/clobber/${key}" \
                              "${directory}/plus/unset/${key}"   \
                              "${directory}/plus/remove/${key}"

   mkdir_if_missing "${finaldirectory}"
   redirect_exekutor "${finaldirectory}/${key}" printf "%s\n" "${value}"
}


get_definition_dir()
{
   log_entry "get_definition_dir" "$@"

   local directory="$1"
   local aux_directory="$2"

   local argument
   local OPTION_OUTPUT_KEY='NO'

   while read -r argument
   do
      case "${argument}" in
         -h*|--help|help)
            make_definition_get_usage
         ;;

         --output-key)
            OPTION_OUTPUT_KEY='YES'
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
   if [ ! -z "${aux_directory}" ]
   then
      read_definition_dir "${aux_directory}"
   fi

   local varkey

   varkey="DEFINITION_${key}"
   if [ "${OPTION_OUTPUT_KEY}" = 'YES' ]
   then
      if [ ! -z "${ZSH_VERSION}" ]
      then
         value="${(P)varkey}"
      else
         value="${!varkey}"
      fi
      printf "%s\n" "${key}='${value}'"
   else
      eval echo "\$$varkey"
   fi

   # https://stackoverflow.com/questions/3601515/how-to-check-if-a-variable-is-set-in-bash
   if [ -z ${varkey+x} ]
   then
      return 4
   fi
}


list_definition_dir()
{
   log_entry "list_definition_dir" "$@"

   local directory="$1"
   local aux_directory="$2"

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
   if [ ! -z "${aux_directory}" ]
   then
      read_definition_dir "${aux_directory}"
   fi

   local lf="
"
   r_print_definitions "${DEFINED_SET_DEFINITIONS}" "${DEFINED_PLUS_DEFINITIONS}" \
                       "" \
                       "=" \
                       "+=" \
                       "" \
                       "'" \
                       "${lf}"

   [ ! -z "${RVAL}" ] && printf "%s\n" "${RVAL}"
}


make_definition_main()
{
   log_entry "make_definition_main" "$@"

   [ -z "${DEFAULT_IFS}" ] && internal_fail "IFS fail"

   local OPTION_ALLOW_UNKNOWN_OPTION="DEFAULT"
   local OPTION_DEFINITION_DIR=".mulle/etc/craft/definition"
   local OPTION_AUX_DEFINITION_DIR=""

   local argument

   while read -r argument
   do
      case "${argument}" in
         -h*|--help|help)
            make_definition_usage
         ;;

         --allow-unknown-option)
            OPTION_ALLOW_UNKNOWN_OPTION='YES'
         ;;

         --no-allow-unknown-option)
            OPTION_ALLOW_UNKNOWN_OPTION='NO'
         ;;

         #
         # with shortcuts
         #
         --definition-dir)
            read -r OPTION_DEFINITION_DIR ||
               make_definition_usage "missing argument to \"${argument}\""
         ;;

         --aux-definition-dir)
            read -r OPTION_AUX_DEFINITION_DIR ||
               make_definition_usage "missing argument to \"${argument}\""
         ;;

         -*)
            make_definition_usage "Unknown definition option \"${argument}\""
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
            return 4
         fi

         ${cmd}_definition_dir "${OPTION_DEFINITION_DIR}" "${OPTION_AUX_DEFINITION_DIR}"
      ;;

      show|keys)
         sed -e 's/^DEFINITION_//' <<< "${KNOWN_DEFINITIONS}" | LC_ALL=C sort -u
      ;;

      set)
         set_definition_dir "${OPTION_DEFINITION_DIR}"
      ;;

      remove|unset)
         unset_definition_dir "${OPTION_DEFINITION_DIR}"
      ;;

      "")
         make_definition_usage
      ;;

      *)
         make_definition_usage "Unknown command ${cmd}"
      ;;
   esac
}

