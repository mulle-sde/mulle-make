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
MULLE_MAKE_PLUGIN_SCRIPT_SH='included'


make::plugin::script::r_build_script_absolutepath()
{
   local definition="$1"
   local definitiondirs="$2"

   if [ -z "${definition}" ]
   then
      log_fluff "There is no BUILD_SCRIPT defined"
      return 1
   fi

   RVAL="${definition}"
   if is_absolutepath "${definition}"
   then
      return 0
   fi

   local searchpath
   local filename
   local directory
   local option
   local tmp
   
   r_dirname "${definition}"
   directory="${RVAL}"

   # DEFINITION_PATH > OPTION_PATH > PATH
   # (as OPTION_PATH is set by mulle-craft)
   searchpath="${OPTION_PATH:-${PATH}}"
   searchpath="${DEFINITION_PATH:-${searchpath}}"

   case "${definition}" in
      /*)
         # clobber searchpath
         searchpath="${directory}"
      ;;

      */*)
         # clobber searchpath
         searchpath=

         # prefer aux
         local definitiondir

         r_reverse_lines "${definitiondirs}"

         .foreachline definitiondir in ${RVAL}
         .do
            r_filepath_concat "${definitiondir}/bin" "${directory}"
            r_colon_concat "${searchpath}" "${RVAL}"
            searchpath="${RVAL}"
         .done

         [ -z "${DEPENDENCY_DIR}" ] && _internal_fail "DEPENDENCY_DIR not set"

         r_filepath_concat "${DEPENDENCY_DIR}/bin" "${directory}"
         r_colon_concat "${searchpath}" "${RVAL}"
         searchpath="${RVAL}"
      ;;

      *)
         # ${DEPENDENCY_DIR}/bin ought to be in PATH already (via --path)
         # also adhere to DEFINITION_PATH, but use "PATH" as default
         r_colon_concat "${MULLE_MAKE_DEFINITION_DIR}/bin" "${searchpath}"
         searchpath="${RVAL}"
      ;;
   esac

   r_basename "${definition}"
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


make::plugin::script::build()
{
   log_entry "make::plugin::script::build" "$@"

   [ $# -ge 9 ] || _internal_fail "api error"

   local cmd="$1"
   local projectinfo="$2"
   local sdk="$3"
   local platform="$4"
   local configuration="$5"
   local srcdir="$6"
   local dstdir="$7"
   local kitchendir="$8"
   local logsdir="$9"

   shift 9

   local buildscript
   local projectdir

   local scriptname

   buildscript="${projectinfo%;*}"
   projectdir="${projectinfo#*;}"

   r_basename "${buildscript}"
   scriptname="${RVAL}"

   local env_common

   make::build::r_env_flags
   env_common="${RVAL}"

   local arguments

   if [ "${OPTION_CORES:-0}" -eq 1 ]
   then
      r_concat "${arguments}" "--serial"
      arguments="${RVAL}"
   fi

   mkdir_if_missing "${kitchendir}"

   # CMAKE_CPP_FLAGS does not exist in cmake
   # so merge into CFLAGS and CXXFLAGS

   local logfile1

   mkdir_if_missing "${logsdir}"

   make::common::r_build_log_name "${logsdir}" "${scriptname}"
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

   local root_dir

   root_dir="$PWD"

   (
      rexekutor cd "${projectdir}" || fail "failed to enter ${projectdir}"

      # redirecting exekutors operate in a subshell!
      logging_redirekt_exekutor "${logfile1}" \
         echo cd "${projectdir}"

      PATH="${OPTION_PATH:-${PATH}}"
      PATH="${DEFINITION_PATH:-${PATH}}"
      log_fluff "PATH temporarily set to $PATH"
      if [ "${MULLE_FLAG_LOG_ENVIRONMENT}" = 'YES' ]
      then
         env | sort >&2
      fi

      #
      # use absolute paths for configure, safer (and easier to read IMO)
      # if you need to pass more stuff, use environment variables as
      #
      if ! logging_tee_eval_exekutor \
                     "${logfile1}" "${teefile1}" \
                     "${env_common}" \
                     "${buildscript}" \
                     ${MULLE_TECHNICAL_FLAGS} \
                     --logfile "${logfile1}" \
                     --teefile "${teefile1}" \
                     --build-dir "'${kitchendir}'" \
                     --root-dir "'${root_dir}'" \
                     --configuration "'${configuration}'" \
                     --install-dir "'${dstdir}'" \
                     --platform "'${platform}'" \
                     --sdk "'${sdk}'" \
                     "${arguments}" \
                     "'${cmd}'"  | ${grepper}
      then
         make::common::build_fail "${logfile1}" "${scriptname}" "${PIPESTATUS[ 0]}" "${greplog}"
      fi
   ) || exit 1
}


#
# this is supposed to work also with DEFINITION_POST_BUILD_SCRIPT, but that feature
# is currently not used. Instead there is a new feature in mulle-dispense that maps
# filenames
#
make::plugin::script::r_test()
{
   log_entry "make::plugin::script::r_test" "$@"

   local srcdir="$1"
   local definition="$2"
   local definitiondirs="$3"

   RVAL=""

   if ! make::plugin::script::r_build_script_absolutepath "${definition}" \
                                                          "${definitiondirs}"
   then
      return 1
   fi

   scriptfile="${RVAL}"
   if [ ! -x "${scriptfile}" ]
   then
      if [ -e "${scriptfile}" ]
      then
         log_warning "There is a build script \"${scriptfile#"${MULLE_USER_PWD}/"}\" but its not executable"
      else
         log_fluff "There is no build script \"${scriptfile#"${MULLE_USER_PWD}/"}\""
      fi
      return 1
   fi

   log_verbose "Found build script \"${scriptfile#"${MULLE_USER_PWD}/"}\""
   MAKE=

   RVAL="${scriptfile};${srcdir}"

   return 0
}


make::plugin::script::initialize()
{
   log_entry "make::plugin::script::initialize"
}

make::plugin::script::initialize

:
