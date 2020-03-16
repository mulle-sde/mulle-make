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
MULLE_MAKE_PLUGIN_AUTOCONF_SH="included"


r_find_autoconf()
{
   local toolname

   toolname="${OPTION_AUTOCONF:-${AUTOCONF:-autoconf}}"
   r_verify_binary "${toolname}" "autoconf" "autoconf"
}


r_find_autoreconf()
{
   local toolname

   toolname="${OPTION_AUTORECONF:-${AUTORECONF:-autoreconf}}"
   r_verify_binary "${toolname}" "autoreconf" "autoreconf"
}


tools_environment_autoconf()
{
   tools_environment_common

   r_find_autoconf
   AUTOCONF="${RVAL}"
   r_find_autoreconf
   AUTORECONF="${RVAL}"

   r_make_for_plugin "autoconf" "no-ninja"
   MAKE="${RVAL}"
}


autoconf_set_needs_rerun()
{
   log_entry "autoconf_set_needs_rerun" "$@"

   local projectfile="$1"

   local configurefile

   r_dirname "${projectfile}"
   configurefile="${RVAL}/configure"

   if [ -f "${configurefile}" ]
   then
      touch "${projectfile}"
   fi
}


build_autoconf()
{
   log_entry "build_autoconf" "$@"

   [ $# -ge 9 ] || internal_fail "api error"

   local command="$1"; shift
   local projectfile="$1"; shift
   local sdk="$1"; shift
   local platform="$1"; shift
   local configuration="$1"; shift
   local srcdir="$1"; shift
   local dstdir="$1"; shift
   local kitchendir="$1"; shift
   local logsdir="$1"; shift

   local projectdir

   r_dirname "${projectfile}"
   projectdir="${RVAL}"

   local env_common

   r_mulle_make_env_flags
   env_common="${RVAL}"

   local autoconf_flags
   local autoreconf_flags

   autoconf_flags="${OPTION_AUTOCONFFLAGS}"
   autoreconf_flags="${OPTION_AUTORECONFFLAGS:--vif}"

   mkdir_if_missing "${kitchendir}"

   # CMAKE_CPP_FLAGS does not exist in cmake
   # so merge into CFLAGS and CXXFLAGS

   local logfile1

   mkdir_if_missing "${logsdir}"

   r_build_log_name "${logsdir}" "autoreconf"
   logfile1="${RVAL}"
   r_build_log_name "${logsdir}" "autoconf"
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
      exekutor cd "${projectdir}" || fail "failed to enter ${projectdir}"

      PATH="${OPTION_PATH:-${PATH}}"
      log_fluff "PATH temporarily set to $PATH"
      if [ "${MULLE_FLAG_LOG_ENVIRONMENT}" = 'YES' ]
      then
         env | sort >&2
      fi

      set -o pipefail # should be set already
      if ! [ -f "aclocal4.am" ]
      then
          # use absolute paths for configure, safer (and easier to read IMO)
         if ! logging_tee_eval_exekutor "${logfile1}" "${teefile1}" \
                                        "${env_common}" \
                                        "${AUTORECONF}" \
                                        "${autoreconf_flags}" | ${grepper}
         then
            autoconf_set_needs_rerun "${projectfile}"
            build_fail "${logfile1}" "autoreconf" "${PIPESTATUS[ 0]}"
         fi
      fi

       # use absolute paths for configure, safer (and easier to read IMO)
      if ! logging_tee_eval_exekutor "${logfile2}" "${teefile2}" \
                                     "${AUTOCONF}" \
                                     "${autoconf_flags}" | ${grepper}
      then
         autoconf_set_needs_rerun "${projectfile}"
         build_fail "${logfile2}" "autoconf" "${PIPESTATUS[ 0]}"
      fi
   ) || exit 1

   #
   # daisy chain configure step
   #
   local PROJECTFILE
   local TOOLNAME=configure

   if ! r_test_configure "${srcdir}"
   then
      fail "Could not run configure for \"${srcdir}"\"
   fi
   PROJECTFILE="${RVAL}"

   [ -z "${PROJECTFILE}" ] && internal_fail "r_test_configure did not set PROJECTFILE"
         #statements

   log_info "Let ${C_RESET_BOLD}${TOOLNAME}${C_INFO} do a reconf of \
${C_MAGENTA}${C_BOLD}${name}${C_INFO} in \"${kitchendir}\" ..."

   if ! build_configure "${command}" \
                        "${PROJECTFILE}"  \
                        "${configuration}" \
                        "${platform}" \
                        "${sdk}" \
                        "${srcdir}" \
                        "${dstdir}" \
                        "${kitchendir}" \
                        "${logsdir}"
   then
      internal_fail "build_configure should exit on failure and not return"
   fi
}


r_test_autoconf()
{
   log_entry "r_test_autoconf" "$@"

   [ $# -eq 1 ] || internal_fail "api error"

   local srcdir="$1"

   local projectfile
   local projectdir

   RVAL=""
   if ! r_find_nearest_matching_pattern "${srcdir}" "configure.ac"
   then
      if ! r_find_nearest_matching_pattern "${srcdir}" "configure.in"
      then
         log_fluff "${srcdir#${MULLE_USER_PWD}/}: There was no autoconf project found."
         return 1
      fi
   fi
   projectfile="${RVAL}"

   if [ ! -z "${OPTION_PHASE}" ]
   then
      local name

      fail "${srcdir#${MULLE_USER_PWD}/}: autoconf does not support build phases
${C_INFO}This is probably a misconfiguration in your sourcetree. Suggest:
${C_RESET_BOLD}mulle-sde dependency unmark <name> no-singlephase"
   fi

   local configurefile

   r_dirname "${projectfile}"
   configurefile="${RVAL}/configure"

   if [ "${OPTION_SKIP_AUTOCONF}" = 'YES' -a -f "${configurefile}" ]
   then
      log_fluff "${srcdir#${MULLE_USER_PWD}/}: Skip to configure due to option SKIP_AUTOCONF being set..."
      return 1
   fi

   if [ "${OPTION_AUTOCONF_CLEAN}" != 'NO' ]
   then
      if [ "${configurefile}" -nt "${projectfile}" ]
      then
         log_fluff "${srcdir#${MULLE_USER_PWD}/}: Autoconf has already run once, skip to configure..."
         return 1
      fi
   fi

   tools_environment_autoconf

   if [ -z "${AUTOCONF}" ]
   then
      log_warning "${srcdir#${MULLE_USER_PWD}/}: Found a `basename -- "${projectfile}"`, but ${C_RESET}${C_BOLD}autoconf${C_WARNING} is not installed"
      return 1
   fi

   if [ -z "${AUTORECONF}" ]
   then
      log_warning "${srcdir#${MULLE_USER_PWD}/}: No autoreconf executable found, will continue though"
   fi

   if [ -z "${MAKE}" ]
   then
      log_warning "${srcdir#${MULLE_USER_PWD}/}: No make executable found"
      return 1
   fi

   RVAL="${projectfile}"
   return 0
}


autoconf_plugin_initialize()
{
   log_entry "autoconf_plugin_initialize"

   if ! build_load_plugin "configure"
   then
      fail "Could not load required plugin \"configure\""
   fi
}

autoconf_plugin_initialize

:
