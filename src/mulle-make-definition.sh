# shellcheck shell=bash
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
MULLE_MAKE_DEFINITION_SH='included'


make::definition::usage()
{
   [ $# -ne 0 ] && log_error "$1"

   cat <<EOF >&2
Usage:
   ${MULLE_USAGE_NAME} ${MULLE_USAGE_COMMAND:-definition} [option] <command>

   Examine and change build definitions. A "definition" is a flag passed to the
   buildtool. This command maintains a permanent ans shareable set of
   definitions. += definitions are used by xcodebuild only.

   There is also the possibility of adding definitions on a per-command basis
   on the commandline for the "make" command.

Commands:
   cat    : show definition file contents
   export : export definition as shell script
   get    : get a specific value
   list   : list defined values
   unset  : remove a key from the definitions
   set    : set a specific value
   show   : list all known builtin keys (excludes plugin specifics)
   write  : write current definitions inta a new definition directory

Options:
   --definition-dir <path> : add to definition directories (.mulle/etc/craft/definition)
   -D<key>=<value>         : set the definition named key to value
   -D<key>+=<value>        : append a += definition for the buildtool
EOF
   exit 1
}


make::definition::cat_usage()
{
   [ $# -ne 0 ] && log_error "$1"

   cat <<EOF >&2
Usage:
   ${MULLE_USAGE_NAME} ${MULLE_USAGE_COMMAND:-definition} cat

   Show setting file contents.
EOF
   exit 1
}

make::definition::export_usage()
{
   [ $# -ne 0 ] && log_error "$1"

   cat <<EOF >&2
Usage:
   ${MULLE_USAGE_NAME} ${MULLE_USAGE_COMMAND:-definition} export [dir]

   Export build settings as mulle-make definition commands

Options:
   --export-command <prefix> : prefix to use instead of \"mulle-make definition\"

EOF
   exit 1
}



make::definition::list_usage()
{
   [ $# -ne 0 ] && log_error "$1"

   cat <<EOF >&2
Usage:
   ${MULLE_USAGE_NAME} ${MULLE_USAGE_COMMAND:-definition} list

   List build settings.
EOF
   exit 1
}


make::definition::get_usage()
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


make::definition::set_usage()
{
   [ $# -ne 0 ] && log_error "$1"

   cat <<EOF >&2
Usage:
   ${MULLE_USAGE_NAME} ${MULLE_USAGE_COMMAND:-definition} set [option] <key> <value>

   Set a build setting. There are two different types of build settings.
   Additive and non-additive. An additive setting will be added to environment
   values and may be emitted as a += setting. A non-additive setting will
   ignore the environment and will be emitted as =. For many build
   settings like CFLAGS additive settings are often preferred, as it lets you
   stack flags (like -m32, -fpic), therefore additive is the default.

   Previous values of the same key can be either appended to or clobbered.
   You would want to "clobber" a value for a build setting like "CC". For
   a build setting like CFLAGS "append" may be a better choice, if you add
   preprocessor definitions for example.

   The --append flag appends over multiple definitions. The value you set
   here still clobbers the old value.

Example:
      ${MULLE_USAGE_NAME} ${MULLE_USAGE_COMMAND:-definition} set FOO foo
      ${MULLE_USAGE_NAME} ${MULLE_USAGE_COMMAND:-definition} set --concat FOO bar

   will produce -DFOO="foo bar", but --append only appends at runtime so:

      ${MULLE_USAGE_NAME} ${MULLE_USAGE_COMMAND:-definition} set --append FOO bar

   will now produce -DFOO="bar"

Options:
   --non-additive : create a non-additive setting
   --concat       : append value to a previous value now
   --concat0      : like concat but without space separation
   --append       : append value to a previous setting at make time (default)
   --append0      : like append but without space separation
   --clobber      : clobber any existing previous value at make time
   --ifempty      : only set if no value exists yet

EOF
   exit 1
}


make::definition::unset_usage()
{
   [ $# -ne 0 ] && log_error "$1"

   cat <<EOF >&2
Usage:
   ${MULLE_USAGE_NAME} ${MULLE_USAGE_COMMAND:-definition} unset <key>

   Remove a build setting.

EOF
   exit 1
}


make::definition::write_usage()
{
   [ $# -ne 0 ] && log_error "$1"

   cat <<EOF >&2
Usage:
   ${MULLE_USAGE_NAME} ${MULLE_USAGE_COMMAND:-definition} write <dir>

   Use definition options to define values or read one or multiple
   definition directories, then write the merged contents into a new
   directory.

EOF
   exit 1
}


#
# grep through project to get the options:_
# grep -E -h -o -w 'DEFINITION_[A-Z0-9_]*[A-Z0-9]' src/*.sh src/plugins/*.sh | LC_ALL=C sort -u
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
DEFINITION_CMAKE
DEFINITION_CMAKE1
DEFINITION_COBJC
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
DEFINITION_LIBRARY_STYLE
DEFINITION_LOG_DIR
DEFINITION_MAKE
DEFINITION_MAKETARGET
DEFINITION_NINJA
DEFINITION_OBJCFLAGS
DEFINITION_OTHER_CFLAGS
DEFINITION_OTHER_CPPFLAGS
DEFINITION_OTHER_CXXFLAGS
DEFINITION_OTHER_LDFLAGS
DEFINITION_OTHER_OBJCFLAGS
DEFINITION_PLATFORM
DEFINITION_PLUGIN_PREFERENCES
DEFINITION_PREFER_XCODEBUILD
DEFINITION_PREFERRED_LIBRARY_STYLE
DEFINITION_PREFIX
DEFINITION_PROJECT_DIALECT
DEFINITION_PROJECT_FILE
DEFINITION_PROJECT_LANGUAGE
DEFINITION_PROJECT_NAME
DEFINITION_SCHEMES
DEFINITION_SDK
DEFINITION_SELECT_CC
DEFINITION_SELECT_COBJC
DEFINITION_SELECT_CXX
DEFINITION_TARGETS
DEFINITION_USE_NINJA
DEFINITION_WARNING_CFLAGS"

KNOWN_DEFINITIONS="${KNOWN_GENERAL_DEFINITIONS}
${KNOWN_AUTOCONF_PLUGIN_DEFINITIONS}
${KNOWN_CMAKE_PLUGIN_DEFINITIONS}
${KNOWN_CONFIGURE_PLUGIN_DEFINITIONS}
${KNOWN_MESON_PLUGIN_DEFINITIONS}
${KNOWN_XCODEBUILD_PLUGIN_DEFINITIONS}"

NO_WARN_DEFINITIONS="${KNOWN_DEFINITIONS}
DEFINITION_MULLE_SDK_PATH
DEFINITION_MULLE_SDK_SUBDIR"

make::definition::handle_definition_options()
{
   local argument="$1"

   local keyvalue

   case "${argument}" in
      '-D'*'+='*)
         #
         # allow multiple -D+= values to appen values
         # useful for -DCFLAGS+= the most often used flag
         #
         make::definition::make_define_plus_keyvalue "${argument:2}" "append"
      ;;

      '-D'*)
         make::definition::make_define_set_keyvalue "${argument:2}" 
      ;;

      '--concat'|'--concat0')
         fail "'Concat' can only be used with the set command"
      ;;

      '--ifempty'|'--append'|'--append0'|'--remove')
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
         make::definition::make_undefine_option "${argument:2}"
      ;;

      *)
         return 1
      ;;
   esac

   return 0
}


make::definition::compgen()
{
   if [ ${ZSH_VERSION+x} ]
   then
      set | sed -n -e 's/\([^=]*\)=.*/\1/p'
   else
      compgen -v
   fi
}


make::definition::all_definition_keys()
{
   log_entry "make::definition::all_definition_keys" "$@"

   if [ -z "${DEFINED_PLUS_DEFINITIONS}" ]
   then
      make::definition::compgen | grep -E '^DEFINITION_'
      return $?
   fi

   #
   # Why are all plus definitions removed ?
   #
   local pattern

   pattern="${DEFINED_PLUS_DEFINITIONS//$'\n'/|}"
   pattern="${pattern%%|}"

   make::definition::compgen \
   | grep -E '^DEFINITION_' \
   | grep -E -v -x "${pattern}"
}


make::definition::clear_all_definition_keys()
{
   log_entry "make::definition::clear_all_definition_keys" "$@"

   local key

   .foreachline key in `compgen -v | grep -E '^DEFINITION_' | sort -u`
   .do
      unset "${key}"
   .done
}


#
#
make::definition::all_userdefined_unknown_keys()
{
   log_entry "make::definition::all_userdefined_unknown_keys" "$@"

   if [ -z "${KNOWN_DEFINITIONS}" ]
   then
      make::definition::all_definition_keys
      return
   fi

   local pattern

   pattern="${KNOWN_DEFINITIONS//$'\n'/|}"
   pattern="${pattern%%|}"

   make::definition::all_definition_keys \
   | grep -E -v -x "${pattern}"
}


#
# plus keys can't happen because of the environment
#
make::definition::all_userdefined_unknown_plus_keys()
{
   log_entry "make::definition::all_userdefined_unknown_plus_keys" "$@"

   if [ -z "${DEFINED_PLUS_DEFINITIONS}" ]
   then
      return
   fi

   local pattern

   pattern="${KNOWN_DEFINITIONS//$'\n'/|}"
   pattern="${pattern%%|}"

   log_debug "${DEFINED_PLUS_DEFINITIONS}"
   grep -E -v -x "${pattern}" <<< "${DEFINED_PLUS_DEFINITIONS}"
}


make::definition::is_plus_key()
{
   log_entry "make::definition::is_plus_key" "$@"

   case "${MULLE_UNAME}" in
      sunos)
         grep -F -q -x -e "$1" <<< "${DEFINED_PLUS_DEFINITIONS}"
      ;;

      *)
         grep -F -q -F -x -e "$1" <<< "${DEFINED_PLUS_DEFINITIONS}"
      ;;
   esac
}


#
# defined for xcodebuild by default
#
make::definition::r_print()
{
   log_entry "make::definition::r_print" "$@"

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

   .foreachline key in ${keys}
   .do
      r_shell_indirect_expand "${key}"
      value="${RVAL}"

      r_concat "${s}" \
               "${prefix}${key#DEFINITION_}${sep}${quote}${value}${quote}" \
               "${concatsep}"
      s="${RVAL}"
   .done

   #
   # emit plus definitions if they are distinguishable
   #
   .foreachline key in ${pluskeys}
   .do
      r_shell_indirect_expand "${key}"
      value="${RVAL}"

      # memo changed this back from plussep to sep, to match test
      # this is for xcodebuild anyway and I never use it now AFAIK
      r_concat "${s}" \
               "${prefix}${key#DEFINITION_}${sep}${quote}${pluspref}${value}${quote}" \
               "${concatsep}"
      s="${RVAL}"
   .done

   RVAL="$s"

   log_debug "User definition: ${s}"
}


#
# defined for xcodebuild by default (\$(inherited))
#
make::definition::emit_userdefined()
{
   log_entry "make::definition::emit_userdefined" "$@"

   local prefix="$1"
   local sep="${2:-=}"
   local plussep="${3:-=}"
   local pluspref="$4"
   local quote="$5"

   local key
   local value

   if [ "${pluspref}" = "-" ]
   then
      pluspref=""
   fi

   #
   # only emit UNKNOWN keys, the known keys are handled
   # by the plugins themselves
   #
   keys="`make::definition::all_userdefined_unknown_keys`"

   #
   # emit plus definitions if they are distinguishable
   #
   if [ "${plussep}" != "${sep}" -o ! -z "${pluspref}" ]
   then
      pluskeys="`make::definition::all_userdefined_unknown_plus_keys`"
   fi

   make::definition::r_print "${keys}" \
                             "${pluskeys}" \
                             "${prefix}" \
                             "${sep}" \
                             "${plussep}" \
                             "${pluspref}" \
                             "${quote}" \
                             " "
   [ ! -z "${RVAL}" ] && printf "%s\n" "${RVAL}"
}


make::definition::check_option_key_without_prefix()
{
   log_entry "make::definition::check_option_key_without_prefix" "$@"

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

   if ! find_line "${NO_WARN_DEFINITIONS}" "DEFINITION_${key}"
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


make::definition::check_key_without_prefix_exists()
{
   log_entry "make::definition::check_key_without_prefix_exists" "$@"

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
make::definition::_make::definition::make_define_option()
{
   log_entry "make::definition::_make::definition::make_define_option" "$@"

   local key="$1"
   local value="$2"
   local option="$3"

   make::definition::check_option_key_without_prefix "${key}"

   local oldvalue
   local optkey

   optkey="DEFINITION_$key"
   r_shell_indirect_expand "${optkey}"
   oldvalue="${RVAL}"

   # this is runtime expansion
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

      'concat'|'concat0')
         fail "Concat can only be used with the set command."
      ;;

      'append')
         r_concat "${oldvalue}" "${value}"
         value="${RVAL}"
      ;;

      'append0')
         value="${oldvalue}${value}"
      ;;

      ''|'clobber')
         if make::definition::check_key_without_prefix_exists "${key}" "${option}" \
            && [ "${oldvalue}" != "${value}" ]
         then
            _log_warning "warning: \"${key}\" previously defined as \
\"${oldvalue}\" now redefined as \"${value}\""
         fi
      ;;
   esac

   printf -v "${optkey}" "%s" "${value}"

   log_fluff "${optkey} defined as '${value}'"
}


make::definition::make_define_option()
{
   log_entry "make::definition::make_define_option" "$@"

   local key="$1"

   if ! make::definition::_make::definition::make_define_option "$@"
   then
      return 1
   fi

   # ensure append doesn't duplicate
   case "${DEFINED_SET_DEFINITIONS}" in
      "DEFINITION_${key}")
         DEFINED_SET_DEFINITIONS="`grep -F -v -x "DEFINITION_${key}" <<< "${DEFINED_SET_DEFINITIONS}" `"
      ;;
   esac

   r_add_line "${DEFINED_SET_DEFINITIONS}" "DEFINITION_${key}"
   DEFINED_SET_DEFINITIONS="${RVAL}"
}


make::definition::make_undefine_option()
{
   log_entry "make::definition::make_undefine_option" "$@"

   local key="$1"

   unset "DEFINITION_${key}"

   DEFINED_SET_DEFINITIONS="`grep -F -v -x -e "DEFINITION_${key}" <<< "${DEFINED_SET_DEFINITIONS}" `"
   DEFINED_PLUS_DEFINITIONS="`grep -F -v -x -e "DEFINITION_${key}" <<< "${DEFINED_PLUS_DEFINITIONS}" `"
}


make::definition::make_define_plusoption()
{
   log_entry "make::definition::make_define_plusoption" "$@"

   local key="$1"

   if ! make::definition::_make::definition::make_define_option "$@"
   then
      return 1
   fi

   # ensure append doesn't duplicate
   case "${DEFINED_PLUS_DEFINITIONS}" in
      "DEFINITION_${key}")
         DEFINED_PLUS_DEFINITIONS="`grep -F -v -x "DEFINITION_${key}" <<< "${DEFINED_PLUS_DEFINITIONS}" `"
      ;;
   esac

   r_add_line "${DEFINED_PLUS_DEFINITIONS}" "DEFINITION_${key}"
   DEFINED_PLUS_DEFINITIONS="${RVAL}"
}


make::definition::make_define_set_keyvalue()
{
   log_entry "make::definition::make_define_set_keyvalue" "$@"

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
   make::definition::make_define_option "${key}" "${value}" "${option}"
}


make::definition::make_define_plus_keyvalue()
{
   log_entry "make::definition::make_define_plus_keyvalue" "$@"

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

   make::definition::make_define_plusoption "${key}" "${value}" "${option}"
}


make::definition::read_defines_dir()
{
   log_entry "make::definition::read_defines_dir" "$@"

   local directory="$1"
   local callback="$2"
   local option="$3"

   local key
   local value
   local read_value
   local filename

   if [ ! -d "${directory}" ]
   then
      log_debug "\"${directory}\" does not exist"
      return
   fi

   local empty

   empty='YES'

   local files

   files="`dir_list_files "${directory}" "[A-Z_]*" "f" `"

   .foreachline filename in ${files}
   .do
      empty='NO'
      r_basename "${filename}"
      key="${RVAL}"

      # ignore files with an extension
      r_identifier "${key}"
#      r_uppercase "${RVAL}"  # can't do this

      if [ "${key}" != "${RVAL}" ]
      then
         log_verbose "${filename} ignored because it's not an identifier"
         .continue
      fi

      # case insensitive fs need this (why ???), maybe for normalization ?
      # unfortunately this conflicts with -DCMAKE_DISABLE_LIBRARY_BZip2=ON
      # r_uppercase "${key}"
      # key="${RVAL}"

      # multiple lines coalesced with space
      read_value="`grep -E -v '^#' "${filename}" | tr '\n' ' '`"
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
   .done

   if [ "${empty}" = 'YES' ]
   then
      log_debug "\"${directory}\" is empty"
   fi
}


#
# it is assumed that the caller (mulle-craft) resolved the UNAME already
#
make::definition::read()
{
   log_entry "make::definition::read" "$@"

   local directory="$1"
   local set_is_plus="${2:-NO}"

   [ "${directory}" = "NONE" ] && return

   if [ ! -d "${directory}" ]
   then
      if [ ! -z "${directory}" ]
      then
         log_fluff "There is no \"${directory#"${MULLE_USER_PWD}/"}\" here (${PWD#"${MULLE_USER_PWD}/"})"
      fi
      return
   fi

   #
   # due to our append scheme, reading the same definition dir twice
   # is disastrous
   #

   local varkey

   r_identifier "${directory}"
   varkey="HASH_${RVAL}"

   r_shell_indirect_expand "${varkey}"
   if [ ! -z "${RVAL}" ]
   then
      log_debug "Did not read directory \"${directory}\" again"
      return
   fi
   printf -v "${varkey}" "READ"


   log_verbose "Read definition ${C_RESET_BOLD}${directory#"${MULLE_USER_PWD}/"}${C_VERBOSE}"

   directory="${directory}"

   local set_callback
   local plus_callback

   set_callback="make::definition::make_define_option"
   plus_callback="make::definition::make_define_plusoption"

   if [ "${set_is_plus}" = 'YES' ]
   then
      set_callback="${plus_callback}"
   fi

   make::definition::read_defines_dir "${directory}/set/unset"    "${set_callback}" "unset"
# old
   make::definition::read_defines_dir "${directory}/set/remove"   "${set_callback}" "remove"
   make::definition::read_defines_dir "${directory}/set/clobber"  "${set_callback}"
   make::definition::read_defines_dir "${directory}/set/ifempty"  "${set_callback}" "ifempty"
   make::definition::read_defines_dir "${directory}/set/append"   "${set_callback}" "append"
   make::definition::read_defines_dir "${directory}/set/append0"  "${set_callback}" "append0"
   make::definition::read_defines_dir "${directory}/set"          "${set_callback}" "append"

   make::definition::read_defines_dir "${directory}/plus/unset"   "${plus_callback}" "unset"
# old
   make::definition::read_defines_dir "${directory}/plus/remove"  "${plus_callback}" "remove"
   make::definition::read_defines_dir "${directory}/plus/clobber" "${plus_callback}"
   make::definition::read_defines_dir "${directory}/plus/ifempty" "${plus_callback}" "ifempty"
   make::definition::read_defines_dir "${directory}/plus/append"  "${plus_callback}" "append"
   make::definition::read_defines_dir "${directory}/plus/append0" "${plus_callback}" "append0"
   make::definition::read_defines_dir "${directory}/plus"         "${plus_callback}" "append"
}


make::definition::export_defines_dir()
{
   log_entry "make::definition::export_defines_dir" "$@"

   local prefix="$1"
   local directory="$2"

   shift 2

   local key
   local value
   local escaped_key
   local escaped_value

   if [ ! -d "${directory}" ]
   then
      log_debug "\"${directory}\" does not exist"
      return
   fi

   local files

   files="`dir_list_files "${directory}" "[A-Z_]*" "f" `"

   .foreachline filename in ${files}
   .do
      r_basename "${filename}"
      key="${RVAL}"

      # ignore files with an extension
      r_identifier "${key}"
#      r_uppercase "${RVAL}"  # can't do this

      if [ "${key}" != "${RVAL}" ]
      then
         log_verbose "${filename} ignored because it's not an identifier"
         .continue
      fi

      value="`cat "${filename}"`"
      r_escaped_singlequotes "${key}"
      escaped_key="${RVAL}"
      r_escaped_singlequotes "${value}"
      escaped_value="${value}"

      rexekutor printf "${prefix} $* '${escaped_key}' '${escaped_value}'\n"
   .done
}


#
# it is assumed that the caller (mulle-craft) resolved the UNAME already
#
make::definition::export()
{
   log_entry "make::definition::export" "$@"

   local directory="$1"
   local prefix="$2"

   if [ ! -d "${directory}" ]
   then
      return
   fi

   make::definition::export_defines_dir "${prefix}" "${directory}/set/unset"   "unset"  "--non-additive"
# old
   make::definition::export_defines_dir "${prefix}" "${directory}/set/remove"  "unset"  "--non-additive"
   make::definition::export_defines_dir "${prefix}" "${directory}/set/clobber" "set"    "--non-additive" "--clobber"
   make::definition::export_defines_dir "${prefix}" "${directory}/set/ifempty" "set"    "--non-additive" "--ifempty"
   make::definition::export_defines_dir "${prefix}" "${directory}/set/append"  "set"    "--non-additive" "--append"
   make::definition::export_defines_dir "${prefix}" "${directory}/set/append0" "set"    "--non-additive" "--append0"
   make::definition::export_defines_dir "${prefix}" "${directory}/set"         "set"    "--non-additive" "--append"

   make::definition::export_defines_dir "${prefix}" "${directory}/plus/unset"   "unset" "--additive" "--unset"
# old
   make::definition::export_defines_dir "${prefix}" "${directory}/plus/remove"  "unset" "--additive" "--remove"
   make::definition::export_defines_dir "${prefix}" "${directory}/plus/clobber" "set"   "--additive" "--clobber"
   make::definition::export_defines_dir "${prefix}" "${directory}/plus/ifempty" "set"   "--additive" "--ifempty"
   make::definition::export_defines_dir "${prefix}" "${directory}/plus/append"  "set"   "--additive" "--append"
   make::definition::export_defines_dir "${prefix}" "${directory}/plus/append0" "set"   "--additive" "--append0"
   make::definition::export_defines_dir "${prefix}" "${directory}/plus"         "set"   "--additive" "--append"
}


#
# it is assumed that the caller (mulle-craft) resolved the UNAME already
#
make::definition::cat()
{
   log_entry "make::definition::cat" "$@"

   local directory="$1"

   [ "${directory}" = "NONE" ] && return

   if [ ! -d "${directory}" ]
   then
      if [ ! -z "${directory}" ]
      then
         log_fluff "There is no \"${directory#"${MULLE_USER_PWD}/"}\" here (${PWD#"${MULLE_USER_PWD}/"})"
      fi
      return
   fi

   local filename

   for filename in `find ${directory} -type f -print`
   do
      log_info "${filename#"${MULLE_USER_PWD}/"}"
      rexekutor cat "${filename}"
   done
}


make::definition::remove_other_keyfiles_than()
{
   log_entry "make::definition::remove_other_keyfiles_than" "$@"

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

make::definition::unset_main()
{
   log_entry "make::definition::unset_main" "$@"

   local directories="$1"

   local argument
   local OPTION_SET_IS_PLUS

	while read -r argument
   do
      case "${argument}" in
         -h*|--help|help)
            make::definition::unset_usage
         ;;

         --set-is-plus)
            OPTION_SET_IS_PLUS='YES'
         ;;

	      -*)
            make::definition::unset_usage "unknown option \"${argument}\""
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
      make::definition::unset_usage "Missing key"
   fi
   key="${argument}"

   if read -r argument
   then
      make::definition::unset_usage "Superfluous argument \"${argument}\""
   fi

   if [ "${directories}" != "NONE" ]
   then
      local directory

      .foreachline directory in ${directories}
      .do
         make::definition::read "${directory}" "${OPTION_SET_IS_PLUS}"
         # operate only on the first
         .break
      .done
   fi

   # remove all possible old settings
   make::definition::remove_other_keyfiles_than "" \
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


make::definition::set_main()
{
   log_entry "make::definition::set_main" "$@"

   local directories="$1"

   local argument
   local OPTION_MODIFIER='set'
   local OPTION_OPERATION
   local OPTION_CONCAT
   local OPTION_SET_IS_PLUS

   while read -r argument
   do
      case "${argument}" in
         -h*|--help|help)
            make::definition::set_usage
         ;;

         -+|--additive)
            OPTION_MODIFIER='plus'
         ;;

         --non-additive)
            OPTION_MODIFIER='set'
         ;;

         --concat)
            OPTION_CONCAT='CONCAT'
         ;;

         --concat0)
            OPTION_CONCAT='CONCAT0'
         ;;

         --append)
            OPTION_OPERATION=
         ;;

         --append0|--ifempty|--remove|--unset|--clobber)
            OPTION_OPERATION="${argument:2}"
         ;;

         # a terrible hack to make all regular defines plus defines
         --set-is-plus)
            OPTION_SET_IS_PLUS='YES'
         ;;

         -*)
            make::definition::set_usage "unknown option \"${argument}\""
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
      make::definition::set_usage "Missing key"
   fi
   key="${argument}"

   if ! read -r argument
   then
      make::definition::set_usage "Missing value"
   fi
   value="${argument}"

   if read -r argument
   then
      make::definition::set_usage "Superfluous argument \"${argument}\""
   fi

   local directory

   .foreachline directory in ${directories}
   .do
      make::definition::read "${directory}" "${OPTION_SET_IS_PLUS}"
      # operate only on the first
      .break
   .done

   make::definition::check_option_key_without_prefix "${key}"

   if [ ! -z "${OPTION_CONCAT}" ]
   then
      local varkey
      local previous

      varkey="DEFINITION_${key}"
      r_shell_indirect_expand "${varkey}"
      previous="${RVAL}"

      case "${OPTION_CONCAT}" in
         'CONCAT')
            r_concat "${previous}" "${value}" "${sep}"
            value="${RVAL}"
         ;;

         'CONCAT0')
            value="${previous}${value}"
         ;;
      esac
   fi

   local finaldirectory

   r_filepath_concat "${directory}" "${OPTION_MODIFIER}" "${OPTION_OPERATION}"
   finaldirectory="${RVAL}"

   # remove all possible old settings
   make::definition::remove_other_keyfiles_than "${finaldirectory}/${key}"         \
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


make::definition::get_main()
{
   log_entry "make::definition::get_main" "$@"

   local directories="$1"

   local argument
   local OPTION_OUTPUT_KEY='NO'
   local OPTION_SET_IS_PLUS

   while read -r argument
   do
      case "${argument}" in
         -h*|--help|help)
            make::definition::get_usage
         ;;

         --output-key)
            OPTION_OUTPUT_KEY='YES'
         ;;

         --set-is-plus)
            OPTION_SET_IS_PLUS='YES'
         ;;

         -*)
            make::definition::get_usage "Unknown option \"${argument}\""
         ;;

         *)
            break
         ;;
      esac
   done

   local key

   if [ -z "${argument}" ]
   then
      make::definition::get_usage "Missing key"
   fi
   key="${argument}"

   if read -r argument
   then
      make::definition::get_usage "Superfluous argument \"${argument}\""
   fi

   local directory

   .foreachline directory in ${directories}
   .do
      make::definition::read "${directory}" "${OPTION_SET_IS_PLUS}"
   .done

   local varkey

   varkey="DEFINITION_${key}"
   if [ "${OPTION_OUTPUT_KEY}" = 'YES' ]
   then
      r_shell_indirect_expand "${varkey}"
      value="${RVAL}"

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


make::definition::list_main()
{
   log_entry "make::definition::list_main" "$@"

   local directories="$1"

   local argument
   local OPTION_SET_IS_PLUS

   while read -r argument
   do
      case "${argument}" in
         -h*|--help|help)
            make::definition::list_usage
         ;;

         --set-is-plus)
            OPTION_SET_IS_PLUS='YES'
         ;;

         -*)
            make::definition::list_usage "Unknown option \"${argument}\""
         ;;

         *)
            break
         ;;
      esac
   done

   if [ ! -z "${argument}" ]
   then
      make::definition::list_usage "Superfluous argument \"${argument}\""
   fi

   if [ "${OPTION_SET_IS_PLUS}" = 'YES' ]
   then
      log_warning "--set-is-plus changes the output of the list command as well"
   fi

   local directory

   .foreachline directory in ${directories}
   .do
      make::definition::read "${directory}" "${OPTION_SET_IS_PLUS}"
   .done

   make::definition::r_print "${DEFINED_SET_DEFINITIONS}" \
                             "${DEFINED_PLUS_DEFINITIONS}" \
                             "" \
                             "=" \
                             "+=" \
                             "" \
                             "'" \
                             $'\n'

   [ ! -z "${RVAL}" ] && printf "%s\n" "${RVAL}"
}



make::definition::export_main()
{
   log_entry "make::definition::export_main" "$@"

   local directories="$1"

   local argument
   local OPTION_PREFIX="mulle-make definition"

   while read -r argument
   do
      case "${argument}" in
         -h*|--help|help)
            make::definition::export_usage
         ;;

         --export-command|--prefix)
            read -r OPTION_PREFIX ||
               make::definition::export_usage "missing argument to \"${argument}\""
         ;;

         -*)
            make::definition::export_usage "Unknown option \"${argument}\""
         ;;

         *)
            break
         ;;
      esac
   done

   if [ ! -z "${argument}" ]
   then
      make::definition::export_usage "Superfluous argument \"${argument}\""
   fi

   local directory

   .foreachline directory in ${directories}
   .do
      make::definition::export "${directory}" "${OPTION_PREFIX}"
   .done
}


make::definition::cat_main()
{
   log_entry "make::definition::cat_main" "$@"

   local directories="$1"

   local argument

   while read -r argument
   do
      case "${argument}" in
         -h*|--help|help)
            make::definition::cat_usage
         ;;

         -*)
            make::definition::cat_usage "Unknown option \"${argument}\""
         ;;

         *)
            break
         ;;
      esac
   done

   if [ ! -z "${argument}" ]
   then
      make::definition::cat_usage "Superfluous argument \"${argument}\""
   fi

   local directory

   .foreachline directory in ${directories}
   .do
      make::definition::cat "${directory}"
   .done
}

#
# defined for xcodebuild by default
#
make::definition::write_key_values()
{
   log_entry "make::definition::write_key_values" "$@"

   local directory="$1"
   local keys="$2"      # list of -DFOO=XX keys separated by linefeed

   [ -z "${keys}" ] && return

   local key
   local value
   local filename

   mkdir_if_missing "${directory}"

   .foreachline key in ${keys}
   .do
      r_shell_indirect_expand "${key}"
      value="${RVAL}"

      r_filepath_concat "${directory}" "${key#DEFINITION_}"
      filename="${RVAL}"

      redirect_exekutor "${filename}" printf "%s\n" "${value}"
   .done
}


make::definition::write_main()
{
   log_entry "make::definition::write_main" "$@"

   local directories="$1"

   local argument
   local OPTION_MODIFIER="clobber"
   local OPTION_SET_IS_PLUS

   while read -r argument
   do
      case "${argument}" in
         -h*|--help|help)
            make::definition::write_usage
         ;;

         --append|--append0|--ifempty|--remove|--unset|--clobber)
            OPTION_MODIFIER="${argument:2}"
         ;;

         --set-is-plus)
            OPTION_SET_IS_PLUS='YES'
         ;;

         -*)
            make::definition::write_usage "Unknown option \"${argument}\""
         ;;

         *)
            break
         ;;
      esac
   done

   local dstdir

   if [ -z "${argument}" ]
   then
      make::definition::write_usage "Missing destination directory"
   fi
   dstdir="${argument}"

   read -r argument
   if [ ! -z "${argument}" ]
   then
      make::definition::write_usage "Superfluous argument \"${argument}\""
   fi

   if [ "${directories}" != "NONE" ]
   then
      local directory

      .foreachline directory in ${directories}
      .do
         make::definition::read "${directory}" "${OPTION_SET_IS_PLUS}"
      .done
   fi

   r_filepath_concat "${dstdir}" "set/${OPTION_MODIFIER}"
   make::definition::write_key_values "${RVAL}" "${DEFINED_SET_DEFINITIONS}"

   r_filepath_concat "${dstdir}" "plus/append"
   make::definition::write_key_values "${RVAL}" "${DEFINED_PLUS_DEFINITIONS}"
}


make::definition::main()
{
   log_entry "make::definition::main" "$@"

   [ -z "${DEFAULT_IFS}" ] && _internal_fail "IFS fail"

   local OPTION_ALLOW_UNKNOWN_OPTION="DEFAULT"
   local OPTION_INFO_DIRS=""

   local argument
   local value

   while read -r argument
   do
      case "${argument}" in
         -h*|--help|help)
            make::definition::usage
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
         --definition-dir|--aux-definition-dir)
            read -r value ||
               make::definition::usage "missing argument to \"${argument}\""

            r_add_line "${OPTION_INFO_DIRS}" "${value}"
            OPTION_INFO_DIRS="${RVAL}"
         ;;

         -*)
            if ! make::definition::handle_definition_options "${argument}"
            then
               make::definition::usage "Unknown definition option \"${argument}\""
            fi
         ;;

         *)
            break
         ;;
      esac
   done

   include "make::common"

   OPTION_INFO_DIRS="${OPTION_INFO_DIRS:-.mulle/etc/craft/definition}"

   local cmd="${argument}"

   case "${cmd}" in
      cat|export|get|list|set)
         make::definition::${cmd}_main "${OPTION_INFO_DIRS}"
      ;;

      show|keys)
         sed -e 's/^DEFINITION_//' <<< "${KNOWN_DEFINITIONS}" | LC_ALL=C sort -u
      ;;

      remove|unset)
         make::definition::unset_main "${OPTION_INFO_DIRS}"
      ;;

      write|merge)
         make::definition::write_main "${OPTION_INFO_DIRS}"
      ;;

      "")
         make::definition::usage
      ;;

      *)
         make::definition::usage "Unknown command ${cmd}"
      ;;
   esac
}

