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


find_autoconf()
{
   local toolname

   toolname="${OPTION_AUTOCONF:-${AUTOCONF:-autoconf}}"
   verify_binary "${toolname}" "autoconf" "autoconf"
}


find_autoreconf()
{
   local toolname

   toolname="${OPTION_AUTORECONF:-${AUTORECONF:-autoreconf}}"
   verify_binary "${toolname}" "autoreconf" "autoreconf"
}


tools_environment_autoconf()
{
   tools_environment_make "no-ninja"

   AUTOCONF="`find_autoconf`"
   AUTORECONF="`find_autoreconf`"
}


build_autoconf()
{
   log_entry "build_autoconf" "$@"

   [ $# -eq 8 ] || internal_fail "api error"

   local command="$1"; shift
   local projectfile="$1"; shift
   local configuration="$1"; shift
   local srcdir="$1"; shift
   local dstdir="$1"; shift
   local builddir="$1"; shift
   local logsdir="$1"; shift
   local sdk="$1"; shift

   local projectdir

   projectdir="`dirname -- "${projectfile}"`"

   local autoconf_flags
   local autoreconf_flags

   autoconf_flags="${OPTION_AUTOCONFFLAGS}"
   autoreconf_flags="${OPTION_AUTORECONFFLAGS:--vif}"

   mkdir_if_missing "${builddir}"

   # CMAKE_CPP_FLAGS does not exist in cmake
   # so merge into CFLAGS and CXXFLAGS

   local logfile1

   mkdir_if_missing "${logsdir}"

   logfile1="`build_log_name "${logsdir}" "autoreconf" "${srcdir}" "${configuration}" "${sdk}"`"
   logfile2="`build_log_name "${logsdir}" "autoconf" "${srcdir}" "${configuration}" "${sdk}"`"

   (
      exekutor cd "${projectdir}" || fail "failed to enter ${projectdir}"

      if [ "${MULLE_FLAG_VERBOSE_BUILD}" = "YES" ]
      then
         logfile1="`safe_tty`"
         logfile2="`safe_tty`"
      fi

      if [ "${MULLE_FLAG_EXEKUTOR_DRY_RUN}" = "YES" ]
      then
         logfile1="/dev/null"
         logfile2="/dev/null"
      fi
      log_verbose "Build log will be in \"${logfile1}\""

      PATH="${BUILDPATH}"
      log_fluff "PATH temporarily set to $PATH"

      if ! [ -f "aclocal4.am" ]
      then
          # use absolute paths for configure, safer (and easier to read IMO)
         if ! logging_redirect_eval_exekutor "${logfile1}" \
                                             "${AUTORECONF}" \
                                             "${autoreconf_flags}"
         then
            build_fail "${logfile1}" "autoreconf"
         fi
      fi

       # use absolute paths for configure, safer (and easier to read IMO)
      if ! logging_redirect_eval_exekutor "${logfile2}" \
                                          "${AUTOCONF}" \
                                          "${autoconf_flags}"
      then
         build_fail "${logfile2}" "autoconf"
      fi
   ) || exit 1

   #
   # daisy chain configure step
   #
   local WASXCODE="NO"
   local PROJECTFILE
   local TOOLNAME=configure
   local AUX_INFO

   if ! test_configure "${configuration}" "${srcdir}"
   then
      fail "Could not run configure for \"${srcdir}"\"
   fi

   [ -z "${PROJECTFILE}" ] && internal_fail "test_configure did not set PROJECTFILE"
         #statements

   log_info "Let ${C_RESET_BOLD}${TOOLNAME}${C_INFO} do a reconf of \
${C_MAGENTA}${C_BOLD}${name}${C_INFO} in \"${builddir}\" ..."

   if ! build_configure "${command}" \
                        "${PROJECTFILE}"  \
                        "${configuration}" \
                        "${srcdir}" \
                        "${dstdir}" \
                        "${builddir}" \
                        "${logsdir}" \
                        "${sdk}"
   then
      internal_fail "build_configure should exit on failure and not return"
   fi
}


test_autoconf()
{
   log_entry "test_autoconf" "$@"

   [ $# -eq 2 ] || internal_fail "api error"

   local configuration="$1"
   local srcdir="$2"

   local projectfile
   local projectdir

   projectfile="`find_nearest_matching_pattern "${srcdir}" "configure.ac"`"
   if [ -z "${projectfile}" ]
   then
      projectfile="`find_nearest_matching_pattern "${srcdir}" "configure.in"`"
      if [ -z "${projectfile}" ]
      then
         log_fluff "There is no autoconf project in \"${srcdir}\""
         return 1
      fi
   fi

   if [ "${OPTION_AUTOCONF_CLEAN}" != "NO" ]
   then
      local configurefile

      configurefile="`dirname -- "${projectfile}"`/configure"
      if [ "${configurefile}" -nt "${projectfile}" ]
      then
         log_fluff "Autoconf has already run once, skip to configure..."
         return 1
      fi
   fi

   tools_environment_autoconf

   if [ -z "${AUTOCONF}" ]
   then
      log_warning "Found a `basename -- "${projectfile}"`, but ${C_RESET}${C_BOLD}autoconf${C_WARNING} is not installed"
      return 1
   fi

   if [ -z "${AUTORECONF}" ]
   then
      log_warning "No autoreconf found, will continue though"
   fi

   if [ -z "${MAKE}" ]
   then
      log_warning "No make found"
      return 1
   fi

   PROJECTFILE="${projectfile}"
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
