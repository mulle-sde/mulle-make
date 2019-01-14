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
MULLE_MAKE_PLUGIN_CONFIGURE_SH="included"


r_convert_path_to_flag()
{
   local path="$1"
   local flag="$2"
   local quote="$3"

   local output
   local munged

   RVAL=""

   IFS=":"
   set -o noglob
   for component in ${path}
   do
      set +o noglob

      if [ -z "${quote}" ]
      then
         component="$(sed -e 's/ /\\ /g' <<< "${component}")"
      fi
      r_concat "${output}" "${flag}${quote}${component}${quote}"
      output="${RVAL}"
   done

   IFS="${DEFAULT_IFS}"
   set +o noglob
}


#
# remove old builddir, create a new one
# depending on configuration cmake with flags
# build stuff into dependencies
#
#
build_configure()
{
   log_entry "build_configure" "$@"

   [ $# -eq 8 ] || internal_fail "api error"

   local cmd="$1"; shift
   local projectfile="$1"; shift
   local configuration="$1"; shift
   local srcdir="$1"; shift
   local dstdir="$1"; shift
   local builddir="$1"; shift
   local logsdir="$1"; shift
   local sdk="$1"; shift

   local configure_flags

   configure_flags="${OPTION_CONFIGURE_FLAGS}"

#   create_dummy_dirs_against_warnings "${mapped}" "${suffix}"

   mkdir_if_missing "${builddir}"

   local cflags
   local cxxflags
   local cppflags
   local ldflags

   r_compiler_cflags_value "${OPTION_CC}" "${configuration}"
   cflags="${RVAL}"
   r_compiler_cxxflags_value "${OPTION_CXX:-${OPTION_CC}}" "${configuration}"
   cxxflags="${RVAL}"
   r_compiler_cppflags_value
   cppflags="${RVAL}"
   r_compiler_ldflags_value
   ldflags="${RVAL}"

   # hackish! changes cflags and friends
   __add_path_tool_flags

   local maketarget
   local arguments

   case "${cmd}" in
      build|project)
         maketarget=
         if [ ! -z "${OPTION_PREFIX}" ]
         then
            arguments="--prefix '${OPTION_PREFIX}'"
         fi
      ;;

      install)
         maketarget="install"
         arguments="--prefix '${dstdir}'"
      ;;

      *)
         maketarget="${cmd}"
         if [ ! -z "${OPTION_PREFIX}" ]
         then
            arguments="--prefix '${OPTION_PREFIX}'"
         fi
      ;;
   esac

   local env_flags
   local passed_keys

   local env_common

   r_mulle_make_env_flags
   env_common="${RVAL}"

   env_flags="${env_common}"

   passed_keys=

   if [ ! -z "${OPTION_CC}" ]
   then
      r_concat "${env_flags}" "CC='${OPTION_CC}'"
      env_flags="${RVAL}"
      r_colon_concat "${passed_keys}" "CC"
      passed_keys="${RVAL}"
   fi
   if [ ! -z "${OPTION_CXX}" ]
   then
      r_concat "${env_flags}" "CXX='${OPTION_CXX}'"
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

   local absprojectdir
   local projectdir

   r_fast_dirname "${projectfile}"
   projectdir="${RVAL}"
   r_absolutepath "${projectdir}"
   absprojectdir="${RVAL}"

   local logfile1
   local logfile2

   mkdir_if_missing "${logsdir}"

   r_build_log_name "${logsdir}" "configure"
   logfile1="${RVAL}"
   r_build_log_name "${logsdir}" "make"
   logfile2="${RVAL}"

   local teefile1
   local teefile2

   teefile1="/dev/null"
   teefile2="/dev/null"

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
      teefile2="${logfile1}"
   fi


   (
      exekutor cd "${builddir}" || fail "failed to enter ${builddir}"

      PATH="${OPTION_PATH:-${PATH}}"
      log_fluff "PATH temporarily set to $PATH"
      if [ "${MULLE_FLAG_LOG_ENVIRONMENT}" = 'YES' ]
      then
         env | sort >&2
      fi


       # use absolute paths for configure, safer (and easier to read IMO)
      if ! logging_redirect_tee_eval_exekutor "${logfile1}" "${teefile1}" \
                                          "${env_flags}" \
                                             "'${absprojectdir}/configure'" \
                                                "${configure_flags}" \
                                                "${arguments}"
      then
         build_fail "${logfile1}" "configure"
      fi

      if ! logging_redirect_tee_eval_exekutor "${logfile2}"  "${teefile2}" \
               "'${MAKE}'" "${MAKE_FLAGS}" ${maketarget}
      then
         build_fail "${logfile2}" "make"
      fi
   ) || exit 1
}


test_configure()
{
   log_entry "test_configure" "$@"

   [ $# -eq 2 ] || internal_fail "api error"

   local configuration="$1"
   local srcdir="$2"

   local projectfile
   local projectdir
   if ! r_find_nearest_matching_pattern "${srcdir}" "configure"
   then
      log_fluff "There is no configure project in \"${srcdir}\""
      return 1
   fi
   projectfile="${RVAL}"
   r_fast_dirname "${projectfile}"
   projectdir="${RVAL}"

   if [ ! -z "${OPTION_PHASE}" ]
   then
      fail "configure does not support build phases
${C_INFO}This is probably a misconfiguration in your sourcetree. Suggest:
${C_RESET_BOLD}mulle-sde dependency unmark <name> no-singlephase"
   fi

   if ! [ -x "${projectdir}/configure" ]
   then
      log_fluff "Configure script in \"${projectdir}\" is not executable"
      return 1
   fi

   case "${MULLE_UNAME}" in
      mingw*)
         if [ -z "${MULLE_MAKE_MINGW_SH}" ]
         then
            . "${MULLE_MAKE_LIBEXEC_DIR}/mulle-make-mingw.sh" || exit 1
         fi
         setup_mingw_buildenvironment
      ;;
   esac

   tools_environment_make "no-ninja" "configure"

   if [ -z "${MAKE}" ]
   then
      log_warning "Found a ./configure, but ${C_RESET}${C_BOLD}make${C_WARNING} is not installed"
      return 1
   fi

   PROJECTFILE="${projectfile}"
   return 0
}


configure_plugin_initialize()
{
   log_entry "configure_plugin_initialize"

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

configure_plugin_initialize

:
