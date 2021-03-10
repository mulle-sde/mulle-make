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
      log_fluff "There is no BUILD_SCRIPT defined"
      return 1
   fi

   RVAL="${OPTION_BUILD_SCRIPT}"
   if is_absolutepath "${OPTION_BUILD_SCRIPT}"
   then
      return 0
   fi

   local searchpath
   local filename
   local directory
   local option

   r_dirname "${OPTION_BUILD_SCRIPT}"
   directory="${RVAL}"

   case "${OPTION_BUILD_SCRIPT}" in
      /*)
         searchpath="${directory}"
      ;;

      */*)
         r_filepath_concat "${MULLE_MAKE_DEFINITION_DIR}/bin" "${directory}"
         searchpath="${RVAL}"

         r_filepath_concat "${DEPENDENCY_DIR}/bin" "${directory}"
         r_colon_concat "${searchpath}" "${RVAL}"
         searchpath="${RVAL}"
      ;;

      *)
         # ${DEPENDENCY_DIR}/bin ought to be in PATH already
         # also adhere to OPTION_PATH, but use "PATH" as default
         r_colon_concat "${MULLE_MAKE_DEFINITION_DIR}/bin" "${OPTION_PATH:-${PATH}}"
         searchpath="${RVAL}"
      ;;
   esac

   r_basename "${OPTION_BUILD_SCRIPT}"
   filename="${RVAL}"

   log_fluff "Looking for script \"${filename}\" in \"${searchpath}\""
   if RVAL="`PATH="${searchpath}" command -v "${filename}"`"
   then
      log_debug "Found \"${RVAL}\""
      return 0
   fi

   log_warning "Failed to find script \"${filename}\" in \"${searchpath}\""

   return 1
}


build_script()
{
   log_entry "build_script" "$@"

   [ $# -ge 9 ] || internal_fail "api error"

   local command="$1"; shift
   local projectinfo="$1"; shift
   local sdk="$1"; shift
   local platform="$1"; shift
   local configuration="$1"; shift
   local srcdir="$1"; shift
   local dstdir="$1"; shift
   local kitchendir="$1"; shift
   local logsdir="$1"; shift

   local buildscript
   local projectdir

   local scriptname

   buildscript="${projectinfo%;*}"
   projectdir="${projectinfo#*;}"

   r_basename "${buildscript}"
   scriptname="${RVAL}"

   local env_common

   r_mulle_make_env_flags
   env_common="${RVAL}"

   mkdir_if_missing "${kitchendir}"

   # CMAKE_CPP_FLAGS does not exist in cmake
   # so merge into CFLAGS and CXXFLAGS

   local logfile1

   mkdir_if_missing "${logsdir}"

   r_build_log_name "${logsdir}" "${scriptname}"
   logfile1="${RVAL}"

   local teefile1
   local grepper

   teefile1="/dev/null"
   grepper="log_grep_warning_error"

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
       # use absolute paths for configure, safer (and easier to read IMO)
      if ! logging_tee_eval_exekutor \
                     "${logfile1}" "${teefile1}" \
                     "${env_common}" \
                     "${buildscript}" \
                     ${MULLE_TECHNICAL_FLAGS} \
                     --logfile "${logfile1}" \
                     --teefile "${teefile1}" \
                     --build-dir "'${kitchendir}'" \
                     --configuration "'${configuration}'" \
                     --install-dir "'${dstdir}'" \
                     --platform "'${platform}'" \
                     --sdk "'${sdk}'" \
                     "'${command}'"  | ${grepper}
      then
         build_fail "${logfile1}" "${scriptname}" "${PIPESTATUS[ 0]}"
      fi
   ) || exit 1
}


r_test_script()
{
   log_entry "r_test_script" "$@"

   [ $# -eq 1 ] || internal_fail "api error"

   local srcdir="$1"

   RVAL=""

   if ! r_build_script_absolutepath
   then
      return 1
   fi

   scriptfile="${RVAL}"
   if [ ! -x "${scriptfile}" ]
   then
      if [ -e "${scriptfile}" ]
      then
         log_warning "There is a build script \"${scriptfile#${MULLE_USER_PWD}/}\" but its not executable"
      else
         log_fluff "There is no build script \"${scriptfile#${MULLE_USER_PWD}/}\""
      fi
      return 1
   fi

   log_verbose "Found build script \"${scriptfile#${MULLE_USER_PWD}/}\""

   RVAL="${scriptfile};${srcdir}"

   return 0
}


script_plugin_initialize()
{
   log_entry "script_plugin_initialize"
}

script_plugin_initialize

:
