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


make::plugin::autoconf::r_find_autoconf()
{
   local toolname

   toolname="${DEFINITION_AUTOCONF:-${AUTOCONF:-autoconf}}"
   make::command::r_verify_binary "${toolname}" "autoconf" "autoconf"
}


make::plugin::autoconf::r_find_autoreconf()
{
   local toolname

   toolname="${DEFINITION_AUTORECONF:-${AUTORECONF:-autoreconf}}"
   make::command::r_verify_binary "${toolname}" "autoreconf" "autoreconf"
}


make::plugin::autoconf::tools_environment()
{
   make::common::tools_environment

   make::plugin::autoconf::r_find_autoconf
   AUTOCONF="${RVAL}"
   make::plugin::autoconf::r_find_autoreconf
   AUTORECONF="${RVAL}"

   make::common::r_make_for_plugin "autoconf" "no-ninja"
   MAKE="${RVAL}"
}


make::plugin::autoconf::set_needs_rerun()
{
   log_entry "make::plugin::autoconf::set_needs_rerun" "$@"

   local projectfile="$1"

   local configurefile

   r_dirname "${projectfile}"
   configurefile="${RVAL}/configure"

   if [ -f "${configurefile}" ]
   then
      touch "${projectfile}"
   fi
}


make::plugin::autoconf::build()
{
   log_entry "make::plugin::autoconf::build" "$@"

   [ $# -ge 9 ] || _internal_fail "api error"

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

   local _absprojectdir
   local _projectdir

   make::common::__project_directories "${projectfile}"

   local absprojectdir="${_absprojectdir}"
   local projectdir="${_projectdir}"

   local env_common

   make::build::r_env_flags
   env_common="${RVAL}"

   local autoconf_flags
   local autoreconf_flags

   autoconf_flags="${DEFINITION_AUTOCONFFLAGS}"
   autoreconf_flags="${DEFINITION_AUTORECONFFLAGS:--vif}"

   mkdir_if_missing "${kitchendir}"

   local logfile1
   local logfile2

   mkdir_if_missing "${logsdir}"

   make::common::r_build_log_name "${logsdir}" "autoreconf"
   logfile1="${RVAL}"
   make::common::r_build_log_name "${logsdir}" "autoconf"
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
      _log_verbose "Build logs will be in \"${logfile1#"${MULLE_USER_PWD}/"}\" \
and \"${logfile2#"${MULLE_USER_PWD}/"}\""
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
      exekutor cd "${projectdir}" || fail "failed to enter ${projectdir}"

      PATH="${OPTION_PATH:-${PATH}}"
      PATH="${DEFINITION_PATH:-${PATH}}"
      log_fluff "PATH temporarily set to $PATH"
      if [ "${MULLE_FLAG_LOG_ENVIRONMENT}" = 'YES' ]
      then
         env | sort >&2
      fi

      local bootstrapper

      if [ -x "autogen.sh" ]
      then
         bootstrapper="autogen.sh"
      else
         if [ -x "bootstrap" ]
         then
            bootstrapper="bootstrap"
         fi
      fi

      local rval 

      if [ ! -z "${bootstrapper}" ]
      then
         make::common::r_build_log_name "${logsdir}" "${bootstrapper}"
         logfile1="${RVAL}"

         if ! NOCONFIGURE=1 logging_tee_eval_exekutor "${logfile1}" "${teefile1}" \
                                                      "${env_common}" \
                                                      "./${bootstrapper}" | ${grepper}
         then
            make::plugin::autoconf::set_needs_rerun "${projectfile}"
            make::common::build_fail "${logfile1}" "${bootstrapper}" "${greplog}"
         fi
      else
         if ! [ -f "aclocal4.am" ]
         then
             # use absolute paths for configure, safer (and easier to read IMO)
            if ! logging_tee_eval_exekutor "${logfile1}" "${teefile1}" \
                                           "${env_common}" \
                                           "${AUTORECONF}" \
                                           "${autoreconf_flags}" | ${grepper}
            then
               rval="${PIPESTATUS[ 0]}"
               make::plugin::autoconf::set_needs_rerun "${projectfile}"
               make::common::build_fail "${logfile1}" "autoreconf" "${rval}" "${greplog}"
            fi
         fi

          # use absolute paths for configure, safer (and easier to read IMO)
         if ! logging_tee_eval_exekutor "${logfile2}" "${teefile2}" \
                                        "${AUTOCONF}" \
                                        "${autoconf_flags}" | ${grepper}
         then
            rval="${PIPESTATUS[ 0]}"
            make::plugin::autoconf::set_needs_rerun "${projectfile}"
            make::common::build_fail "${logfile2}" "autoconf" "${rval}" "${greplog}"
         fi
      fi
   ) || exit 1

   #
   # daisy chain configure step
   #
   local PROJECTFILE
   local TOOLNAME=configure

   if ! make::plugin::configure::r_test "${srcdir}" "" ""
   then
      fail "Could not run configure for \"${srcdir}"\"
   fi
   PROJECTFILE="${RVAL}"

   [ -z "${PROJECTFILE}" ] \
   && _internal_fail "make::plugin::configure::r_test did not set PROJECTFILE"
         #statements

   _log_info "Let ${C_RESET_BOLD}${TOOLNAME}${C_INFO} do a reconf of \
${C_MAGENTA}${C_BOLD}${name}${C_INFO} in \"${kitchendir}\" ..."

   if ! make::plugin::configure::build "${cmd}" \
                                       "${PROJECTFILE}"  \
                                       "${sdk}" \
                                       "${platform}" \
                                       "${configuration}" \
                                       "${srcdir}" \
                                       "${dstdir}" \
                                       "${kitchendir}" \
                                       "${logsdir}"
   then
      _internal_fail "make::plugin::configure::build should exit on failure and not return"
   fi
}


make::plugin::autoconf::r_test()
{
   log_entry "make::plugin::autoconf::r_test" "$@"

   [ $# -eq 3 ] || _internal_fail "api error"

   local srcdir="$1"
   local definition="$2"
   local definitiondirs="$3"

   local projectfile
   local projectdir

   RVAL=""
   if ! make::common::r_find_nearest_matching_pattern "${srcdir}" "configure.ac"
   then
      if ! make::common::r_find_nearest_matching_pattern "${srcdir}" "configure.in"
      then
         log_fluff "${srcdir#"${MULLE_USER_PWD}/"}: There was no autoconf project found."
         return 1
      fi
   fi
   projectfile="${RVAL}"

   if [ ! -z "${OPTION_PHASE}" ]
   then
      local name

      fail "${srcdir#"${MULLE_USER_PWD}/"}: autoconf does not support build phases
${C_INFO}This is probably a misconfiguration in your sourcetree. Suggest:
${C_RESET_BOLD}mulle-sde dependency mark <name> singlephase"
   fi

   local configurefile

   r_dirname "${projectfile}"
   configurefile="${RVAL}/configure"

   if [ "${DEFINITION_SKIP_AUTOCONF}" = 'YES' -a -f "${configurefile}" ]
   then
      _log_fluff "${srcdir#"${MULLE_USER_PWD}/"}: Skip to configure due to \
option SKIP_AUTOCONF being set..."
      return 1
   fi

   if [ "${DEFINITION_AUTOCONF_CLEAN}" != 'NO' ]
   then
      if [ "${configurefile}" -nt "${projectfile}" ]
      then
         _log_fluff "${srcdir#"${MULLE_USER_PWD}/"}: Autoconf has already run \
once, skip to configure..."
         return 1
      fi
   fi

   make::plugin::autoconf::tools_environment

   if [ -z "${AUTOCONF}" ]
   then
      r_basename "${projectfile}"
      _log_warning "${srcdir#"${MULLE_USER_PWD}/"}: Found a \"${RVAL}\", but \
${C_RESET}${C_BOLD}autoconf${C_WARNING} is not installed"
      return 1
   fi

   if [ -z "${AUTORECONF}" ]
   then
      _log_warning "${srcdir#"${MULLE_USER_PWD}/"}: No autoreconf executable \
found, will continue though"
   fi

   if [ -z "${MAKE}" ]
   then
      log_warning "${srcdir#"${MULLE_USER_PWD}/"}: No make executable found"
      return 1
   fi

   log_verbose "Found autoconf project \"${projectfile#"${MULLE_USER_PWD}/"}\""

   RVAL="${projectfile}"
   return 0
}


make::plugin::autoconf::initialize()
{
   log_entry "make::plugin::autoconf::initialize"

   if ! make::plugin::load "configure"
   then
      fail "Could not load required plugin \"configure\""
   fi
}

make::plugin::autoconf::initialize

:
