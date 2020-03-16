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
r_platform_meson_backend()
{
   local toolname

   toolname="${OPTION_NINJA:-${NINJA:-ninja}}"
   r_verify_binary "${toolname}" "ninja" "ninja"
}


r_find_meson()
{
   local toolname

   toolname="${OPTION_MESON:-${MESON:-meson}}"
   r_verify_binary "${toolname}" "meson" "meson"
}


tools_environment_meson()
{
   log_entry "tools_environment_meson" "$@"

   r_find_meson
   MESON="${RVAL}"

   tools_environment_common

   local backend

   r_platform_meson_backend
   NINJA="${RVAL}"

   r_basename "${RVAL}"
   backend="${RVAL#mock-}"

   MESON_BACKEND="${OPTION_MESON_BACKEND:-${backend}}"
}


r_meson_sdk_parameter()
{
   local sdk="$1"

   RVAL=""
   case "${MULLE_UNAME}" in
      "darwin")
         r_compiler_get_sdkpath "${sdk}"
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
build_meson()
{
   log_entry "build_meson" "$@"

   [ $# -ge 9 ] || internal_fail "api error"

   local cmd="$1"; shift
   local projectfile="$1"; shift
   local sdk="$1"; shift
   local platform="$1"; shift
   local configuration="$1"; shift
   local srcdir="$1"; shift
   local dstdir="$1"; shift
   local kitchendir="$1"; shift
   local logsdir="$1"; shift

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

   r_compiler_cflags_value "${OPTION_CC}" "${configuration}" 'NO'
   cflags="${RVAL}"
   r_compiler_cxxflags_value "${OPTION_CXX:-${OPTION_CC}}" "${configuration}" 'NO'
   cxxflags="${RVAL}"
   r_compiler_cppflags_value "${OPTION_INCLUDE_PATH}"
   cppflags="${RVAL}"
   r_compiler_ldflags_value "${OPTION_CC}" "${configuration}"
   ldflags="${RVAL}"

   __add_path_tool_flags

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

   r_projectdir_relative_to_builddir "${absbuilddir}" "${absprojectdir}"
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
   meson_flags="${OPTION_MESONFLAGS}"

   local maketarget

   case "${cmd}" in
      build|project|make)
         maketarget=
         if [ ! -z "${OPTION_PREFIX}" ]
         then
            r_concat "${meson_flags}" "--prefix '${OPTION_PREFIX}'"
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
         if [ ! -z "${OPTION_PREFIX}" ]
         then
            r_concat "${meson_flags}" "--prefix '${OPTION_PREFIX}'"
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

   if [ ! -z "${OPTION_CC}" ]
   then
      r_concat "${meson_env}" "CC='${OPTION_CC}'"
      meson_env="${RVAL}"
      r_colon_concat "${passed_keys}" "CC"
      passed_keys="${RVAL}"
   fi

   if [ ! -z "${OPTION_CXX}" ]
   then
      r_concat "${meson_env}" "CXX='${OPTION_CXX}'"
      meson_env="${RVAL}"
      r_colon_concat "${passed_keys}" "CXX"
      passed_keys="${RVAL}"
   fi

   local sdkparameter

   r_meson_sdk_parameter "${sdk}"
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

   ninja_flags="${OPTION_NINJAFLAGS}"

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

   other_buildsettings="`emit_userdefined_definitions "-D " "=" "=" "" "'"`"
   if [ ! -z "${other_buildsettings}" ]
   then
      r_concat "${meson_flags}" "${other_buildsettings}"
      meson_flags="${RVAL}"
   fi

   local env_common

   r_mulle_make_env_flags
   env_common="${RVAL}"

   local logfile1
   local logfile2

   mkdir_if_missing "${logsdir}"

   r_build_log_name "${logsdir}" "meson"
   logfile1="${RVAL}"
   r_build_log_name "${logsdir}" "ninja"
   logfile2="${RVAL}"

   local teefile1
   local teefile2
   local grepper

   teefile1="/dev/null"
   teefile2="/dev/null"
   grepper="log_grep_warning_error"

   if [ "$MULLE_FLAG_EXEKUTOR_DRY_RUN" = 'YES' ]
   then
      logfile1="/dev/null"
      logfile2="/dev/null"
   else
      log_verbose "Build logs will be in \"${logfile1#${MULLE_USER_PWD}/}\" and \"${logfile2#${MULLE_USER_PWD}/}\""
   fi

   if [ "$MULLE_FLAG_LOG_VERBOSE" = 'YES' ]
   then
      r_safe_tty
      teefile1="${RVAL}"
      teefile2="${teefile1}"
      grepper="log_delete_all"
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

      set -o pipefail # should be set already

      if ! logging_tee_eval_exekutor "${logfile1}" "${teefile1}" \
               "${env_common}" \
               "${meson_env}" \
               "'${MESON}'" --backend "'${MESON_BACKEND}'" \
                            "${meson_flags}" \
                            "'${kitchendir}'" | ${grepper}
      then
         build_fail "${logfile1}" "meson" "${PIPESTATUS[ 0]}"
      fi

      exekutor cd "${kitchendir}" || fail "failed to enter ${kitchendir}"

      if ! logging_tee_eval_exekutor "${logfile2}" "${teefile2}" \
               "${env_common}" \
               "'${NINJA}'" "${ninja_flags}" ${maketarget} | ${grepper}
      then
         build_fail "${logfile2}" "ninja" "${PIPESTATUS[ 0]}"
      fi
   ) || exit 1
}


r_test_meson()
{
   log_entry "test_meson" "$@"

   [ $# -eq 1 ] || internal_fail "api error"

   local srcdir="$1"

   local projectfile
   local projectdir

   RVAL=""
   if ! r_find_nearest_matching_pattern "${srcdir}" "meson.build"
   then
      log_fluff "${srcdir#${MULLE_USER_PWD}/}: There was no meson.build file found"
      return 1
   fi
   projectfile="${RVAL}"

   if [ ! -z "${OPTION_PHASE}" ]
   then
      fail "${srcdir#${MULLE_USER_PWD}/}: meson does not support build phases"
   fi

   tools_environment_meson

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

   log_verbose "${srcdir#${MULLE_USER_PWD}/}: Found meson project file \"${projectfile}\""

   RVAL="${projectfile}"

   return 0
}


meson_plugin_initialize()
{
   log_entry "meson_plugin_initialize"

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

meson_plugin_initialize

:

