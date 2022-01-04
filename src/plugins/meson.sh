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
MULLE_MAKE_PLUGIN_MESON_SH="included"



#
# Meson can work with several backends.
# Let's do only ninja at first and add xcodebuild or vs later.
#
make::plugin::meson::r_platform_backend()
{
   local toolname

   toolname="${DEFINITION_NINJA:-${NINJA:-ninja}}"
   make::command::r_verify_binary "${toolname}" "ninja" "ninja"
}


make::plugin::meson::r_find_meson()
{
   local toolname

   toolname="${DEFINITION_MESON:-${MESON:-meson}}"
   make::command::r_verify_binary "${toolname}" "meson" "meson"
}


make::plugin::meson::tools_environment()
{
   log_entry "make::plugin::meson::tools_environment" "$@"

   make::plugin::meson::r_find_meson
   MESON="${RVAL}"

   make::common::tools_environment

   local backend

   make::plugin::meson::r_platform_backend
   NINJA="${RVAL}"

   r_basename "${RVAL}"
   backend="${RVAL#mock-}"

   MESON_BACKEND="${DEFINITION_MESON_BACKEND:-${backend}}"
}


make::plugin::meson::r_sdk_parameter()
{
   local sdk="$1"

   RVAL=""
   case "${MULLE_UNAME}" in
      "darwin")
         make::compiler::r_get_sdkpath "${sdk}"
         if [ ! -z "${RVAL}" ]
         then
            log_fluff "Set meson sdk to \"${RVAL}\""
            RVAL="-isysroot '${RVAL}'"
         fi
      ;;
   esac
}


#
# remove old kitchendir, create a new one
# depending on configuration meson with flags
# build stuff into dependencies
# TODO: cache commandline in a file $ and emit instead of rebuilding it every time
#
make::plugin::meson::build()
{
   log_entry "make::plugin::meson::build" "$@"

   [ $# -ge 9 ] || internal_fail "api error"

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

   [ -z "${cmd}" ] && internal_fail "cmd is empty"
   [ -z "${projectfile}" ] && internal_fail "projectfile is empty"
   [ -z "${configuration}" ] && internal_fail "configuration is empty"
   [ -z "${srcdir}" ] && internal_fail "srcdir is empty"
   [ -z "${kitchendir}" ] && internal_fail "kitchendir is empty"
   [ -z "${logsdir}" ] && internal_fail "logsdir is empty"
   [ -z "${sdk}" ] && internal_fail "sdk is empty"
   [ -z "${platform}" ] && internal_fail "sdk is empty"

   # need this now
   mkdir_if_missing "${kitchendir}"

   local cflags
   local cxxflags
   local cppflags
   local ldflags

   make::compiler::r_cflags_value "${DEFINITION_CC}" "${configuration}" 'NO'
   cflags="${RVAL}"
   make::compiler::r_cxxflags_value "${DEFINITION_CXX:-${DEFINITION_CC}}" "${configuration}" 'NO'
   cxxflags="${RVAL}"
   make::compiler::r_cppflags_value "${DEFINITION_CC}" "${DEFINITION_INCLUDE_PATH}"
   cppflags="${RVAL}"
   make::compiler::r_ldflags_value "${DEFINITION_CC}" "${configuration}"
   ldflags="${RVAL}"

   local sdkflags

   make::common::r_sdkpath_tool_flags "${sdk}"
   sdkflags="${RVAL}"
   r_concat "${cppflags}" "${sdkflags}"
   cppflags="${RVAL}"
   r_concat "${ldflags}" "${sdkflags}"
   ldflags="${RVAL}"

   make::common::r_headerpath_preprocessor_flags
   r_concat "${cppflags}" "${RVAL}"
   cppflags="${RVAL}"

   make::common::r_librarypath_linker_flags
   r_concat "${ldflags}" "${RVAL}"
   ldflags="${RVAL}"

   #
   # basically adds some flags for android based on chosen SDK
   #
   make::sdk::r_cflags "${sdk}" "${platform}"
   r_concat "${cflags}" "${RVAL}"

   #
   # not really sure about what MESON wants, assume its like configure
   # and does CPPFLAGS

   # if [ ! -z "${cppflags}" ]
   # then
   #    r_concat "${cflags}" "${cppflags}"
   #    cflags="${RVAL}"
   #
   #    if [ "${DEFINITION_PROJECT_LANGUAGE}" != "c" ]
   #    then
   #       r_concat "${cxxflags}" "${cppflags}"
   #       cxxflags="${RVAL}"
   #    fi
   # fi

   local rel_project_dir
   local absbuilddir
   local absprojectdir
   local projectdir

   r_dirname "${projectfile}"
   projectdir="${RVAL}"
   r_simplified_absolutepath "${projectdir}"
   absprojectdir="${RVAL}"
   r_simplified_absolutepath "${kitchendir}"
   absbuilddir="${RVAL}"

   make::common::r_projectdir_relative_to_builddir "${absbuilddir}" "${absprojectdir}"
   rel_project_dir="${RVAL}"

   if [ "${MULLE_FLAG_LOG_SETTINGS}" = 'YES' ]
   then
      log_trace2 "cflags:          ${cflags}"
      log_trace2 "cppflags:        ${cppflags}"
      log_trace2 "cxxflags:        ${cxxflags}"
      log_trace2 "ldflags:         ${ldflags}"
      log_trace2 "projectfile:     ${projectfile}"
      log_trace2 "projectdir:      ${projectdir}"
      log_trace2 "absprojectdir:   ${absprojectdir}"
      log_trace2 "absbuilddir:     ${absbuilddir}"
      log_trace2 "rel_project_dir: ${rel_project_dir}"
      log_trace2 "PWD:             ${PWD}"
   fi

   local meson_flags
   local meson_env
   local passed_keys

   passed_keys=
   meson_env=
   meson_flags="${DEFINITION_MESONFLAGS}"

   local maketarget

   case "${cmd}" in
      build|project|make)
         maketarget=
         if [ ! -z "${DEFINITION_PREFIX}" ]
         then
            r_concat "${meson_flags}" "--prefix '${DEFINITION_PREFIX}'"
            meson_flags="${RVAL}"
         fi
      ;;

      install)
         [ -z "${dstdir}" ] && internal_fail "srcdir is empty"
         maketarget="install"
         r_concat "${meson_flags}" "--prefix '${dstdir}'"
         meson_flags="${RVAL}"
      ;;

      *)
         maketarget="${cmd}"
         if [ ! -z "${DEFINITION_PREFIX}" ]
         then
            r_concat "${meson_flags}" "--prefix '${DEFINITION_PREFIX}'"
            meson_flags="${RVAL}"
         fi
      ;;
   esac

   if [ ! -z "${configuration}" ]
   then
      configuration="$(tr 'A-Z' 'a-z' <<< "${configuration}" )"
      r_concat "${meson_flags}" "--buildtype '${configuration}'"
      meson_flags="${RVAL}"
   fi

   if [ ! -z "${DEFINITION_CC}" ]
   then
      r_concat "${meson_env}" "CC='${DEFINITION_CC}'"
      meson_env="${RVAL}"
      r_colon_concat "${passed_keys}" "CC"
      passed_keys="${RVAL}"
   fi

   if [ ! -z "${DEFINITION_CXX}" ]
   then
      r_concat "${meson_env}" "CXX='${DEFINITION_CXX}'"
      meson_env="${RVAL}"
      r_colon_concat "${passed_keys}" "CXX"
      passed_keys="${RVAL}"
   fi

   local sdkparameter

   make::plugin::meson::r_sdk_parameter "${sdk}"
   sdkparameter="${RVAL}"

   if [ ! -z "${sdkparameter}" ]
   then
      r_concat "${cppflags}" "${sdkparameter}"
      cppflags="${RVAL}"
   fi

   if [ ! -z "${cppflags}" ]
   then
      r_concat "${meson_env}" "CPPFLAGS='${cppflags}'"
      meson_env="${RVAL}"
      r_colon_concat "${passed_keys}" "CPPFLAGS"
      passed_keys="${RVAL}"
   fi
   if [ ! -z "${cflags}" ]
   then
      r_concat "${meson_env}" "CFLAGS='${cflags}'"
      meson_env="${RVAL}"
      r_colon_concat "${passed_keys}" "CFLAGS"
      passed_keys="${RVAL}"
   fi
   if [ ! -z "${cxxflags}" ]
   then
      r_concat "${meson_env}" "CXXFLAGS='${cxxflags}'"
      meson_env="${RVAL}"
      r_colon_concat "${passed_keys}" "CXXFLAGS"
      passed_keys="${RVAL}"
   fi
   if [ ! -z "${ldflags}" ]
   then
      r_concat "${meson_env}" "LDFLAGS='${ldflags}'"
      meson_env="${RVAL}"
      r_colon_concat "${passed_keys}" "LDFLAGS"
      passed_keys="${RVAL}"
   fi

   # always pass at least a trailing :
   r_concat "${meson_env}" "__MULLE_MAKE_ENV_ARGS='${passed_keys}':"
   meson_env="${RVAL}"

   local ninja_flags

   ninja_flags="${DEFINITION_NINJAFLAGS}"

   if [ ! -z "${OPTION_CORES}" ]
   then
      r_concat "${ninja_flags}" "-j '${OPTION_CORES}'"
      ninja_flags="${RVAL}"
   fi

   if [ "${MULLE_FLAG_LOG_VERBOSE}" = 'YES' ]
   then
      r_concat "${ninja_flags}" "-v"
      ninja_flags="${RVAL}"
   fi

   local other_buildsettings

   other_buildsettings="`make::definition::emit_userdefined "-D " "=" "=" "" "'"`"
   if [ ! -z "${other_buildsettings}" ]
   then
      r_concat "${meson_flags}" "${other_buildsettings}"
      meson_flags="${RVAL}"
   fi

   local env_common

   make::build::r_env_flags
   env_common="${RVAL}"

   local logfile1
   local logfile2

   mkdir_if_missing "${logsdir}"

   make::common::r_build_log_name "${logsdir}" "meson"
   logfile1="${RVAL}"
   make::common::r_build_log_name "${logsdir}" "ninja"
   logfile2="${RVAL}"

   local teefile1
   local teefile2
   local grepper
   local greplog

   teefile1="/dev/null"
   teefile2="/dev/null"
   grepper="make::common::log_grep_warning_error"
   greplog='YES'

   if [ "$MULLE_FLAG_EXEKUTOR_DRY_RUN" = 'YES' ]
   then
      logfile1="/dev/null"
      logfile2="/dev/null"
   else
      log_verbose "Build logs will be in \"${logfile1#${MULLE_USER_PWD}/}\" and \"${logfile2#${MULLE_USER_PWD}/}\""
   fi

   if [ "$MULLE_FLAG_LOG_VERBOSE" = 'YES' ]
   then
      make::common::r_safe_tty
      teefile1="${RVAL}"
      teefile2="${teefile1}"
      grepper="make::common::log_delete_all"
      greplog='NO'
   fi

   (
      PATH="${OPTION_PATH:-${PATH}}"
      log_fluff "PATH temporarily set to $PATH"
      if [ "${MULLE_FLAG_LOG_ENVIRONMENT}" = 'YES' ]
      then
         env | sort >&2
      fi

      #
      # If there is already something built and we changed environment vars,
      # we should call `meson configure`.
      # But then we would need to do the checking if
      # something changed ourselves instead of meson doing it. Stupid IMO.
      # Let's just force clean...
      #
      if [ -e "${kitchendir}/meson-private" ]
      then
         rmdir_safer "${kitchendir}"
      fi

      if ! logging_tee_eval_exekutor "${logfile1}" "${teefile1}" \
               "${env_common}" \
               "${meson_env}" \
               "'${MESON}'" --backend "'${MESON_BACKEND}'" \
                            "${meson_flags}" \
                            "'${kitchendir}'" | ${grepper}
      then
         make::common::build_fail "${logfile1}" "meson" "${PIPESTATUS[ 0]}" "${greplog}"
      fi

      exekutor cd "${kitchendir}" || fail "failed to enter ${kitchendir}"

      if ! logging_tee_eval_exekutor "${logfile2}" "${teefile2}" \
               "${env_common}" \
               "'${NINJA}'" "${ninja_flags}" ${maketarget} | ${grepper}
      then
         make::common::build_fail "${logfile2}" "ninja" "${PIPESTATUS[ 0]}" "${greplog}"
      fi
   ) || exit 1
}


make::plugin::meson::r_test()
{
   log_entry "make::plugin::meson::r_test" "$@"

   [ $# -eq 1 ] || internal_fail "api error"

   local srcdir="$1"

   local projectfile
   local projectdir

   RVAL=""
   if ! make::common::r_find_nearest_matching_pattern "${srcdir}" "meson.build"
   then
      log_fluff "${srcdir#${MULLE_USER_PWD}/}: There was no meson.build file found"
      return 1
   fi
   projectfile="${RVAL}"

   if [ ! -z "${OPTION_PHASE}" ]
   then
      fail "${srcdir#${MULLE_USER_PWD}/}: meson does not support build phases"
   fi

   make::plugin::meson::tools_environment

   if [ -z "${MESON}" ]
   then
      log_warning "${srcdir#${MULLE_USER_PWD}/}: Found a meson.build, but \
${C_RESET}${C_BOLD}meson${C_WARNING} is not installed"
      return 1
   fi

   if [ -z "${MESON_BACKEND}" ]
   then
      fail "${srcdir#${MULLE_USER_PWD}/}: No meson backend available"
   fi

   log_verbose "Found meson project \"${projectfile#${MULLE_USER_PWD}/}\""

   RVAL="${projectfile}"

   return 0
}


make::plugin::meson::initialize()
{
   log_entry "make::plugin::meson::initialize"

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

make::plugin::meson::initialize

:

