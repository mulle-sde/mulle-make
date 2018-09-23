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
MULLE_MAKE_PLUGIN_SCRIPT_SH="included"


r_build_script_absolutepath()
{
   if [ -z "${OPTION_BUILD_SCRIPT}" ]
   then
      log_fluff "There was no mulle-make info directory defined on the commandline"
      return 1
   fi

   RVAL="${OPTION_BUILD_SCRIPT}"
   if is_absolutepath "${OPTION_BUILD_SCRIPT}"
   then
      return
   fi

   # use MULLE_MAKE_INFO_DIR otherwise PWD
   r_absolutepath "${OPTION_BUILD_SCRIPT}" "${MULLE_MAKE_INFO_DIR}"
}


build_script()
{
   log_entry "build_script" "$@"

   [ $# -eq 8 ] || internal_fail "api error"

   local command="$1"; shift
   local projectfile="$1"; shift
   local configuration="$1"; shift
   local srcdir="$1"; shift
   local dstdir="$1"; shift
   local builddir="$1"; shift
   local logsdir="$1"; shift
   local sdk="$1"; shift

   local buildscript
   local projectdir
   local RVAL
   local scriptname

   r_build_script_absolutepath
   buildscript="${RVAL}"

   r_fast_basename "${buildscript}"
   scriptname="${RVAL}"

   r_fast_dirname "${projectfile}"
   projectdir="${RVAL}"

   local env_common

   r_mulle_make_env_flags
   env_common="${RVAL}"

   mkdir_if_missing "${builddir}"

   # CMAKE_CPP_FLAGS does not exist in cmake
   # so merge into CFLAGS and CXXFLAGS

   local logfile1

   mkdir_if_missing "${logsdir}"

   r_build_log_name "${logsdir}" "${scriptname}" "${srcdir}" "${configuration}" "${sdk}"
   logfile1="${RVAL}"

   if [ "$MULLE_FLAG_EXEKUTOR_DRY_RUN" = "YES" ]
   then
      logfile1="/dev/null"
   else
      if [ "$MULLE_FLAG_LOG_VERBOSE" = "YES" ]
      then
         logfile1="`safe_tty`"
      else
         log_verbose "Build log will be in \"${logfile1}\""
      fi
   fi

   (
      exekutor cd "${projectdir}" || fail "failed to enter ${projectdir}"

      PATH="${OPTION_PATH:-${PATH}}"
      log_fluff "PATH temporarily set to $PATH"
      if [ "${MULLE_FLAG_LOG_ENVIRONMENT}" = "YES" ]
      then
         env | sort >&2
      fi

       # use absolute paths for configure, safer (and easier to read IMO)
      if ! logging_redirect_eval_exekutor "${logfile1}" \
                                          "${env_common}" \
                                          "${buildscript}" \
                                          --build-dir "'${builddir}'" \
                                          --install-dir "'${dstdir}'" \
                                          --configuration "'${configuration}'" \
                                          --sdk "'${sdk}'" \
                                          "'${command}'"
      then
         build_fail "${logfile1}" "${scriptname}"
      fi
   ) || exit 1
}


test_script()
{
   log_entry "test_script" "$@"

   [ $# -eq 2 ] || internal_fail "api error"

   local configuration="$1"
   local srcdir="$2"

   if ! r_build_script_absolutepath
   then
      return 1
   fi

   scriptfile="${RVAL}"
   if [ ! -x "${scriptfile}" ]
   then
      if [ -e "${scriptfile}" ]
      then
         log_warning "There is a build script \"${scriptfile}\" but its not executable"
      else
         log_fluff "There is no build script \"${scriptfile}\""
      fi
      return 1
   fi

   PROJECTFILE="${srcdir}/unknown"
   return 0
}


script_plugin_initialize()
{
   log_entry "script_plugin_initialize"
}

script_plugin_initialize

:
