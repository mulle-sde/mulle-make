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
MULLE_MAKE_PLUGIN_XCODEBUILD_SH="included"


make::plugin::xcodebuild::r_find_xcodebuild()
{
   local toolname

   toolname="${DEFINITION_XCODEBUILD:-${XCODEBUILD:-xcodebuild}}"
   make::command::r_verify_binary "${toolname}" "xcodebuild" "xcodebuild"
}


make::plugin::xcodebuild::tools_environment()
{
   make::common::tools_environment

   make::plugin::xcodebuild::r_find_xcodebuild "$@"
   XCODEBUILD="${RVAL}"
}


#
# use this with += ?
#
# _xcode_get_setting()
# {
#    log_entry "_xcode_get_setting" "$@"
#
#    exekutor "${XCODEBUILD:-xcodebuild}" -showBuildSettings "$@" || fail "failed to read xcode settings"
# }
#
#
# xcode_get_setting()
# {
#    log_entry "xcode_get_setting" "$@"
#
#    local key=$1; shift
#
#    _xcode_get_setting "$@" | egrep "^[ ]*${key}" | sed 's/^[^=]*=[ ]*\(.*\)/\1/'
#
#    return 0
# }


#
# Let's not inherit here
#
make::plugin::xcodebuild::r_convert_path_to_value()
{
   log_entry "make::plugin::xcodebuild::r_convert_path_to_value" "$@"

   local filepath="$1"
   local inherit="${2:-NO}"

   local output
   local component

   IFS=':'
   shell_disable_glob
   for component in ${filepath}
   do
      r_concat "${output}" "${component}"
      output="${RVAL}"
   done
   IFS="${DEFAULT_IFS}"
   shell_enable_glob

   if [ "${inherit}" = 'YES' -a ! -z "${inherit}" ]
   then
      r_concat "${output}" "\$(inherited)"
      output="${RVAL}"
   fi

   RVAL="${output}"
}


#
# called from make::plugin::xcodebuild::build for each required scheme and target
#
make::plugin::xcodebuild::_build()
{
   log_entry "make::plugin::xcodebuild::_build" "$@"

   [ $# -ge 11 ] || _internal_fail "api error"

   local cmd="$1"
   local projectfile="$2"
   local sdk="$3"
   local platform="$4"
   local configuration="$5"
   local srcdir="$6"
   local dstdir="$7"
   local kitchendir="$8"
   local logsdir="$9"

   shift 9

   local schemename="$1"
   local targetname="$2"

   shift 2

   [ ! -z "${configuration}" ] || _internal_fail "configuration is empty"
   [ ! -z "${srcdir}" ]        || _internal_fail "srcdir is empty"
   [ ! -z "${kitchendir}" ]    || _internal_fail "kitchendir is empty"
   [ ! -z "${sdk}" ]           || _internal_fail "sdk is empty"
   [ ! -z "${projectfile}" ]   || _internal_fail "project is empty"

   local _absprojectdir
   local _projectdir

   make::common::__project_directories "${projectfile}"

   local absprojectdir="${_absprojectdir}"
   local projectdir="${_projectdir}"

   #
   # xctool needs schemes, these are often autocreated, which xctool cant do
   # xcodebuild can just use a target
   # xctool is by and large useless fluff IMO
   #
   if [ "${TOOLNAME}" = "xctool"  -a -z "${schemename}" ]
   then
      if [ ! -z "${targetname}" ]
      then
         schemename="${targetname}"
         targetname=
      else
         cat <<EOF >&2
Please specify a scheme to compile in ${MAKE_DIR}/${name}/SCHEME for
xctool and be sure that this scheme exists and is shared. Or delete
${HOME}/.mulle/etc/craft/definition/xcodebuild and use xcodebuild (preferred).
EOF
         exit 1
      fi
   fi

   # now don't load any settings anymoe
   local action

   case "${cmd}" in
      build|project)
         action="build"
         dstdir="" # paranoia
      ;;

      install)
         action="install"
      ;;
   esac

   local arguments

   arguments=""
   if [ ! -z "${projectname}" ]
   then
      r_concat "${arguments}" "-project '${projectname}'"
      arguments="${RVAL}"
   fi

   if [ ! -z "${sdk}" ]
   then
      if [ "${sdk}" = "Default" ]
      then
# stay flexible by not providing SDK
#         r_concat "${arguments}" "-sdk 'macosx'"
#         arguments="${RVAL}"
      :
      else
         r_concat "${arguments}" "-sdk '${sdk}'"
         arguments="${RVAL}"
      fi
   fi

   if [ -z "${schemename}" -a -z "${targetname}" ]
   then
      r_concat "${arguments}" "-alltargets"
      arguments="${RVAL}"
   else
      if [ ! -z "${schemename}" ]
      then
         r_concat "${arguments}" "-scheme '${schemename}'"
         arguments="${RVAL}"
   else
         r_concat "${arguments}" "-target '${targetname}'"
         arguments="${RVAL}"
      fi
   fi

   if [ ! -z "${configuration}" ]
   then
      r_concat "${arguments}" "-configuration '${configuration}'"
      arguments="${RVAL}"
   fi

   # an empty xcconfig is nice, because it acts as a reset for ?
   local xcconfig

   xcconfig="${DEFINITION_XCODE_XCCONFIG_FILE}"
   if [ ! -z "${xcconfig}" ]
   then
      r_concat "${arguments}" "-xcconfig '${xcconfig}'"
      arguments="${RVAL}"
   fi

   local buildsettings
   local user_buildsettings
   local absbuilddir

   # don't expand stuff with variables
   case "${kitchendir}" in
      ""|*$*)
         absbuilddir="${kitchendir}"
      ;;

      *)
         r_absolutepath "${kitchendir}"
         absbuilddir="${RVAL}"
      ;;
   esac

   buildsettings="ARCHS='${DEFINITION_XCODE_ARCHS:-\${ARCHS_STANDARD}}'"
   r_concat "${buildsettings}" "DSTROOT='${dstdir:-${absbuilddir}}'"
   buildsettings="${RVAL}"
   r_concat "${buildsettings}" "OBJROOT='${absbuilddir}/obj'"
   buildsettings="${RVAL}"
   r_concat "${buildsettings}" "SYMROOT='${absbuilddir}/'"
   buildsettings="${RVAL}"
   r_concat "${buildsettings}" "ONLY_ACTIVE_ARCH='${DEFINITION_ONLY_ACTIVE_ARCH:-NO}'"
   buildsettings="${RVAL}"

   local env_common

   make::build::r_env_flags
   env_common="${RVAL}"

   if [ ! -z "${DEFINITION_CFLAGS}" ]
   then
      r_concat "${buildsettings}" "CFLAGS='${DEFINITION_CFLAGS}'"
      buildsettings="${RVAL}"
   fi
   if [ ! -z "${DEFINITION_CXXFLAGS}" ]
   then
      r_concat "${buildsettings}" "CXXFLAGS='${DEFINITION_CXXFLAGS}'"
      buildsettings="${RVAL}"
   fi
   if [ ! -z "${DEFINITION_LDFLAGS}" ]
   then
      r_concat "${buildsettings}" "LDFLAGS='${DEFINITION_LDFLAGS}'"
      buildsettings="${RVAL}"
   fi

   if [ ! -z "${DEFINITION_OTHER_CFLAGS}" ]
   then
      r_concat "${buildsettings}" "OTHER_CFLAGS='${DEFINITION_OTHER_CFLAGS}'"
      buildsettings="${RVAL}"
   fi
   if [ ! -z "${DEFINITION_OTHER_CXXFLAGS}" ]
   then
      r_concat "${buildsettings}" "OTHER_CXXFLAGS='${DEFINITION_OTHER_CXXFLAGS}'"
      buildsettings="${RVAL}"
   fi
   if [ ! -z "${DEFINITION_OTHER_LDFLAGS}" ]
   then
      r_concat "${buildsettings}" "OTHER_LDFLAGS='${DEFINITION_OTHER_LDFLAGS}'"
      buildsettings="${RVAL}"
   fi

   if [ ! -z "${DEFINITION_PREFIX}" ]
   then
      r_concat "${buildsettings}" "DYLIB_INSTALL_NAME_BASE='${DEFINITION_PREFIX}'"
      buildsettings="${RVAL}"
   fi

   if [ "${OPTION_XCODE_HAS_PROPER_SKIP_INSTALL:-NO}" = 'NO' ]
   then
      r_concat "${buildsettings}" "SKIP_INSTALL=NO"
      buildsettings="${RVAL}"
   fi

   #
   # create HEADER_SEARCH_PATHS LIBRARY_SEARCH_PATHS FRAMEWORK_SEARCH_PATHS
   # we don't inherit
   #
   local value

   make::plugin::xcodebuild::r_convert_path_to_value "${DEFINITION_INCLUDE_PATH}"
   value="${RVAL}"
   if [ ! -z "${value}" ]
   then
      r_concat "${buildsettings}" "HEADER_SEARCH_PATHS='${value}'"
      buildsettings="${RVAL}"
   fi

   make::plugin::xcodebuild::r_convert_path_to_value "${DEFINITION_LIB_PATH}"
   value="${RVAL}"
   if [ ! -z "${value}" ]
   then
      r_concat "${buildsettings}" "LIBRARY_SEARCH_PATHS='${value}'"
      buildsettings="${RVAL}"
   fi

   make::plugin::xcodebuild::r_convert_path_to_value "${DEFINITION_FRAMEWORKS_PATH}"
   value="${RVAL}"
   if [ ! -z "${value}" ]
   then
      r_concat "${buildsettings}" "FRAMEWORK_SEARCH_PATHS='${value}'"
      buildsettings="${RVAL}"
   fi

   user_buildsettings="`make::definition::emit_userdefined '' '=' '+=' '$(inherited) ' "'" `"
   if [ ! -z "${user_buildsettings}" ]
   then
      r_concat "${buildsettings}" "${user_buildsettings}"
      buildsettings="${RVAL}"
   fi

   local logfile1

   mkdir_if_missing "${logsdir}"
   make::common::r_build_log_name "${logsdir}" "${TOOLNAME}"
   logfile1="${RVAL}"

   local teefile1
   local grepper
   local greplog

   teefile1="/dev/null"
   grepper="make::common::log_grep_warning_error"
   greplog='YES'

   if [ "$MULLE_FLAG_EXEKUTOR_DRY_RUN" = 'YES' ]
   then
      logfile1="/dev/null"
   else
      log_verbose "Build logs will be in \"${logfile1#"${MULLE_USER_PWD}/"}\""
   fi

   if [ "$MULLE_FLAG_LOG_VERBOSE" = 'YES' ]
   then
      make::common::r_safe_tty
      teefile1="${RVAL}"
      grepper="make::common::log_delete_all"
      greplog='NO'
   fi

   (
      shell_disable_glob  # prevent bash from expanding glob

      exekutor cd "${projectdir}" || exit 1

      # DONT READ CONFIG SETTING IN THIS INDENT ?

      PATH="${OPTION_PATH:-${PATH}}"
      PATH="${DEFINITION_PATH:-${PATH}}"
      log_fluff "PATH temporarily set to $PATH"
      if [ "${MULLE_FLAG_LOG_ENVIRONMENT}" = 'YES' ]
      then
         env | sort >&2
      fi

      # if it doesn't install, probably SKIP_INSTALL is set
      if ! logging_tee_eval_exekutor "${logfile1}" "${teefile1}" \
                                     "${env_common}" \
                                "'${XCODEBUILD}'" "'${action}'" \
                                       "${arguments}" \
                                       "${buildsettings}" | ${grepper}
      then
         make::common::build_fail "${logfile}" "${TOOLNAME}" "${PIPESTATUS[ 0]}" "${greplog}"
      fi
   ) || exit 1
}


make::plugin::xcodebuild::build()
{
   log_entry "make::plugin::xcodebuild::build" "$@"

   local project="$2"

   local scheme

   .foreachline scheme in ${DEFINITION_SCHEMES}
   .do
      log_fluff "Building scheme \"${scheme}\" of \"${project}\" ..."
      make::plugin::xcodebuild::_build "$@" "${scheme}" ""
   .done

   local target

   .foreachline target in ${DEFINITION_TARGETS}
   .do
      log_fluff "Building target \"${target}\" of \"${project}\" ..."
      make::plugin::xcodebuild::_build "$@" "" "${target}"
   .done

   if [ -z "${DEFINITION_SCHEMES}" -a -z "${DEFINITION_TARGETS}" ]
   then
      log_fluff "Building project \"${project}\" ..."
      make::plugin::xcodebuild::_build "$@" "" ""
   fi
}


make::plugin::xcodebuild::r_test()
{
   log_entry "make::plugin::xcodebuild::r_test" "$@"

   local srcdir="$1"
   local definition="$2"
   local definitiondirs="$3"

   local projectfile
   local projectdir

   local projectname

   RVAL=""

    # always pass project directly
   projectfile="${DEFINITION_PROJECT_FILE}"
   if [ ! -z "${projectfile}" ]
   then
      projectfile="${srcdir}/${projectfile}"
   fi

   if [ ! -d "${projectfile}" ]
   then
      make::common::r_find_nearest_matching_pattern "${srcdir}" "*.xcodeproj" "${name}.xcodeproj"
      projectfile="${RVAL}"
      if [ -z "${projectfile}" ]
      then
         log_fluff "${srcdir#"${MULLE_USER_PWD}/"}: There is no Xcode project in \"${srcdir}\""
         return 1
      fi
   fi

   if [ ! -z "${OPTION_PHASE}" ]
   then
      fail "${srcdir#"${MULLE_USER_PWD}/"}: Xcode does not support build phases"
   fi

   r_dirname "${projectfile}"
   projectdir="${RVAL}"
   make::plugin::xcodebuild::tools_environment "${projectdir}"

   if [ -z "${XCODEBUILD}" ]
   then
      log_verbose "${srcdir#"${MULLE_USER_PWD}/"}: No xcodebuild found."
      return 1
   fi

   r_basename "${XCODEBUILD}"
   TOOLNAME="${RVAL}"

   log_verbose "Found Xcode project \"${projectfile#"${MULLE_USER_PWD}/"}\""

   RVAL="${projectfile}"

   return 0
}


make::plugin::xcodebuild::initialize()
{
   log_entry "make::plugin::xcodebuild::initialize"

   if [ -z "${MULLE_STRING_SH}" ]
   then
      . "${MULLE_BASHFUNCTIONS_LIBEXEC_DIR}/mulle-string.sh" || return 1
   fi
   if [ -z "${MULLE_PATH_SH}" ]
   then
      . "${MULLE_BASHFUNCTIONS_LIBEXEC_DIR}/mulle-path.sh" || return 1
   fi
   if [ -z "${MULLE_FILE_SH}" ]
   then
      . "${MULLE_BASHFUNCTIONS_LIBEXEC_DIR}/mulle-file.sh" || return 1
   fi
}

make::plugin::xcodebuild::initialize

:

