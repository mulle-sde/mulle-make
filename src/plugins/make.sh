#! /usr/bin/env bash
#
#   Copyright (c) 2021 Nat! - Mulle kybernetiK
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
MULLE_MAKE_PLUGIN_MAKE_SH="included"


#
# remove old kitchendir, create a new one
# depending on configuration cmake with flags
# build stuff into dependencies
#
#
build_make()
{
   log_entry "build_make" "$@"

   [ $# -ge 9 ] || internal_fail "api error"

   local cmd="$1"
   local projectfile="$2"
   local sdk="$3"
   local platform="$4"
   local configuration="$5"
   local srcdir="$6"
   local dstdir="$7" # unused
   local kitchendir="$8"
   local logsdir="$9"

   shift 9

   local make_flags

   make_flags="${DEFINITION_MAKEFLAGS}"

#   create_dummy_dirs_against_warnings "${mapped}" "${suffix}"

   mkdir_if_missing "${kitchendir}"

   local cflags
   local cxxflags
   local cppflags
   local ldflags

   r_compiler_cflags_value "${DEFINITION_CC}" "${configuration}"
   cflags="${RVAL}"
   r_compiler_cxxflags_value "${DEFINITION_CXX:-${DEFINITION_CC}}" "${configuration}"
   cxxflags="${RVAL}"
   r_compiler_cppflags_value "${DEFINITION_CC}" "${configuration}"
   cppflags="${RVAL}"
   r_compiler_ldflags_value "${DEFINITION_CC}" "${configuration}"
   ldflags="${RVAL}"

   # hackish! changes cflags and friends to possibly add dependency dir ?
   local sdkflags

   r_sdkpath_tool_flags "${sdk}"
   sdkflags="${RVAL}"
   r_concat "${cppflags}" "${sdkflags}"
   cppflags="${RVAL}"
   r_concat "${ldflags}" "${sdkflags}"
   ldflags="${RVAL}"

   r_headerpath_preprocessor_flags
   r_concat "${cppflags}" "${RVAL}"
   cppflags="${RVAL}"

   r_librarypath_linker_flags
   r_concat "${ldflags}" "${RVAL}"
   ldflags="${RVAL}"

   #
   # basically adds some flags for android based on chosen SDK
   #
   r_sdk_cflags "${sdk}" "${platform}"
   r_concat "${cflags}" "${RVAL}"
   cflags="${RVAL}"

#
# cppflags should not be duplicated into CFLAGS and CXXFLAGS for makefile.
# cmake has no CMAKE_CPP_FLAGS so we have to do it there

#
#   if [ ! -z "${cppflags}" ]
#   then
#      r_concat "${cflags}" "${cppflags}"
#      cflags="${RVAL}"
#
#      if [ "${DEFINITION_PROJECT_LANGUAGE}" != "c" ]
#      then
#         r_concat "${cxxflags}" "${cppflags}"
#         cxxflags="${RVAL}"
#      fi
#   fi

   local maketarget
   local arguments

   case "${cmd}" in
      build|project)
         maketarget=all
      ;;

      install)
         [ -z "${dstdir}" ] && internal_fail "dstdir is empty"
         maketarget="install"
      ;;

      *)
         maketarget="${cmd}"
      ;;
   esac

   dstdir="${dstdir}"
   if [ ! -z "${dstdir}" ]
   then
      if [ "${MULLE_FLAG_LOG_VERBOSE}" = 'YES' ]
      then
         installflags="${installflags} -v"
      fi

      arguments="PREFIX='${dstdir}' DESTDIR='${dstdir}' INSTALLFLAGS='${installflags}'"
   fi

   local libsuffix
   local exesuffix

   case "${MULLE_UNAME}" in
      windows|mingw)
         exesuffix=".exe"
      ;;
   esac

   case "${DEFINITION_LIBRARY_STYLE}" in
      standalone)
         fail "make does not support standalone builds"
      ;;

      dynamic)
         libsuffix=.so  # hackage
      ;;

      static)
         libsuffix=.a  # hackage

         r_concat "${cppflags}" --static
         cppflags="${RVAL}"
      ;;
   esac

   local env_flags
   local passed_keys

   r_mulle_make_env_flags
   env_flags="${RVAL}"

   passed_keys=

   if [ ! -z "${DEFINITION_CC}" ]
   then
      r_concat "${env_flags}" "CC='${DEFINITION_CC}'"
      env_flags="${RVAL}"
      r_colon_concat "${passed_keys}" "CC"
      passed_keys="${RVAL}"
   fi
   if [ ! -z "${DEFINITION_CXX}" ]
   then
      r_concat "${env_flags}" "CXX='${DEFINITION_CXX}'"
      env_flags="${RVAL}"
      r_colon_concat "${passed_keys}" "CXX"
      passed_keys="${RVAL}"
   fi
   if [ ! -z "${cppflags}" ]
   then
      r_concat "${env_flags}" "CPPFLAGS='${cppflags}'"
      env_flags="${RVAL}"
      r_colon_concat "${passed_keys}" "CPPFLAGS"
      passed_keys="${RVAL}"
   fi
   if [ ! -z "${cflags}" ]
   then
      r_concat "${env_flags}" "CFLAGS='${cflags}'"
      env_flags="${RVAL}"
      r_colon_concat "${passed_keys}" "CFLAGS"
      passed_keys="${RVAL}"
   fi
   if [ ! -z "${cxxflags}" ]
   then
      r_concat "${env_flags}" "CXXFLAGS='${cxxflags}'"
      env_flags="${RVAL}"
      r_colon_concat "${passed_keys}" "CXXFLAGS"
      passed_keys="${RVAL}"
   fi
   if [ ! -z "${ldflags}" ]
   then
      r_concat "${env_flags}" "LDFLAGS='${ldflags}'"
      env_flags="${RVAL}"
      r_colon_concat "${passed_keys}" "LDFLAGS"
      passed_keys="${RVAL}"
   fi

   # always pass at least a trailing :

   r_concat "${env_flags}" "__MULLE_MAKE_ENV_ARGS='${passed_keys}':"
   env_flags="${RVAL}"

   local make_flags

   r_build_make_flags "${MAKE}" "${DEFINITION_MAKEFLAGS}"
   r_concat "${arguments}" "${RVAL}"
   arguments="${RVAL}"

   local absprojectdir
   local projectdir

   r_dirname "${projectfile}"
   projectdir="${RVAL}"
   r_absolutepath "${projectdir}"
   absprojectdir="${RVAL}"

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
      log_trace2 "MAKEFLAGS:       ${MAKEFLAGS}"
      log_trace2 "arguments:       ${arguments}"
   fi

   local logfile1

   mkdir_if_missing "${logsdir}"

   r_build_log_name "${logsdir}" "make"
   logfile1="${RVAL}"

   local teefile1
   local grepper
   local greplog

   teefile1="/dev/null"
   grepper="log_grep_warning_error"
   greplog='YES'

   if [ "$MULLE_FLAG_EXEKUTOR_DRY_RUN" = 'YES' ]
   then
      logfile1="/dev/null"
   else
      log_verbose "Build logs will be in \"${logfile1#${MULLE_USER_PWD}/}\""
   fi

   if [ "$MULLE_FLAG_LOG_VERBOSE" = 'YES' ]
   then
      r_safe_tty
      teefile1="${RVAL}"
      grepper="log_delete_all"
      greplog="NO"
   fi

   (
      # make doesn't work in kitchendir
      exekutor cd "${absprojectdir}" || fail "failed to enter ${absprojectdir}"

      r_concat "${arguments}" "BUILD_DIR='${kitchendir}'"
      arguments="${RVAL}"

      if [ ! -z "${exesuffix}" ]
      then
         r_concat "${arguments}" "EXE_SUFFIX='${exesuffix}'"
         arguments="${RVAL}"
      fi

      if [ ! -z "${libsuffix}" ]
      then
         r_concat "${arguments}" "LIB_SUFFIX='${libsuffix}'"
         arguments="${RVAL}"
      fi

      PATH="${DEFINITION_PATH:-${PATH}}"
      log_fluff "PATH temporarily set to $PATH"
      if [ "${MULLE_FLAG_LOG_ENVIRONMENT}" = 'YES' ]
      then
         env | sort >&2
      fi

      # some need all install combo
      if [ "${maketarget}" = "install" ]
      then
         if ! logging_tee_eval_exekutor "${logfile1}" "${teefile1}" \
                  "'${MAKE}'" "${MAKEFLAGS}" "${arguments}" "all"  | ${grepper}
         then
            build_fail "${logfile1}" "make" "${PIPESTATUS[ 0]}" "${greplog}"
         fi
      fi

      if ! logging_tee_eval_exekutor "${logfile1}" "${teefile1}" \
               "'${MAKE}'" "${MAKEFLAGS}" "${arguments}" "${maketarget}" | ${grepper}
      then
         build_fail "${logfile1}" "make" "${PIPESTATUS[ 0]}" "${greplog}"
      fi

   ) || exit 1
}


r_test_make()
{
   log_entry "r_test_make" "$@"

   [ $# -eq 1 ] || internal_fail "api error"

   local srcdir="$1"

   local projectfile
   local projectdir

   if ! r_find_nearest_matching_pattern "${srcdir}" "Makefile"
   then
      log_fluff "There is no makefile project in \"${srcdir}\""
      RVAL=""
      return 4
   fi

   projectfile="${RVAL}"
   r_dirname "${projectfile}"
   projectdir="${RVAL}"

   if [ ! -z "${OPTION_PHASE}" ]
   then
      fail "${srcdir#${MULLE_USER_PWD}/}: Make does not support build phases
${C_INFO}This is probably a misconfiguration in your sourcetree. Suggest:
${C_RESET_BOLD}mulle-sde dependency mark <name> singlephase"
   fi

   case "${MULLE_UNAME}" in
      mingw*)#
         include_mulle_tool_library "platform" "mingw"
         setup_mingw_buildenvironment
      ;;
   esac

   r_make_for_plugin "make" "no-ninja"
   MAKE="${RVAL}"

   tools_environment_common

   log_verbose "Found makefile script \"${projectfile#${MULLE_USER_PWD}/}\""

   RVAL="${projectfile}"
   return 0
}


make_plugin_initialize()
{
   log_entry "make_plugin_initialize"

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

make_plugin_initialize

:
