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


# make::plugin::meson::r_sdk_parameter()
# {
#    local sdk="$1"
#
#    RVAL=""
#    case "${MULLE_UNAME}" in
#       "darwin")
#          make::compiler::r_get_sdkpath "${sdk}"
#          if [ ! -z "${RVAL}" ]
#          then
#             log_fluff "Set meson sdk to \"${RVAL}\""
#             RVAL="-isysroot '${RVAL}'"
#          fi
#       ;;
#    esac
# }


#
# remove old kitchendir, create a new one
# depending on configuration meson with flags
# build stuff into dependencies
# TODO: cache commandline in a file $ and emit instead of rebuilding it every time
#
make::plugin::meson::build()
{
   log_entry "make::plugin::meson::build" "$@"

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

   [ -z "${cmd}" ] && _internal_fail "cmd is empty"
   [ -z "${projectfile}" ] && _internal_fail "projectfile is empty"
   [ -z "${configuration}" ] && _internal_fail "configuration is empty"
   [ -z "${srcdir}" ] && _internal_fail "srcdir is empty"
   [ -z "${kitchendir}" ] && _internal_fail "kitchendir is empty"
   [ -z "${logsdir}" ] && _internal_fail "logsdir is empty"
   [ -z "${sdk}" ] && _internal_fail "sdk is empty"
   [ -z "${platform}" ] && _internal_fail "sdk is empty"

   # need this now
   mkdir_if_missing "${kitchendir}"

   local _c_compiler
   local _cxx_compiler
   local _cppflags
   local _cflags
   local _cxxflags
   local _ldflags
   local _pkgconfigpath

   make::common::__std_flags "${sdk}" "${platform}" "${configuration}"

   local c_compiler="${_c_compiler}"
   local cxx_compiler="${_cxx_compiler}"
   local cppflags="${_cppflags}"
   local cflags="${_cflags}"
   local cxxflags="${_cxxflags}"
   local ldflags="${_ldflags}"
   local pkgconfigpath="${_pkgconfigpath}"
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


   local _absprojectdir
   local _projectdir

   make::common::__project_directories "${projectfile}"

   local absprojectdir="${_absprojectdir}"
   local projectdir="${_projectdir}"


   log_setting "PWD:             ${PWD}"

   local meson_flags

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
         [ -z "${dstdir}" ] && _internal_fail "srcdir is empty"
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
      r_lowercase "${configuration}"
      r_concat "${meson_flags}" "--buildtype '${RVAL}'"
      meson_flags="${RVAL}"
   fi

#   local sdkparameter
#
#   make::plugin::meson::r_sdk_parameter "${sdk}"
#   sdkparameter="${RVAL}"
#
#   if [ ! -z "${sdkparameter}" ]
#   then
#      r_concat "${cppflags}" "${sdkparameter}"
#      cppflags="${RVAL}"
#   fi

   local meson_env

   make::common::r_env_std_flags "${c_compiler}" \
                                 "${cxx_compiler}" \
                                 "${cppflags}" \
                                 "${cflags}" \
                                 "${cxxflags}" \
                                 "${ldflags}" \
                                 "${pkgconfigpath}"

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

#   local other_buildsettings
#
#   other_buildsettings="`make::definition::emit_userdefined "-D" "=" "=" "" "'"`"
#   if [ ! -z "${other_buildsettings}" ]
#   then
#      r_concat "${meson_flags}" "${other_buildsettings}"
#      meson_flags="${RVAL}"
#   fi

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
      log_verbose "Build logs will be in \"${logfile1#"${MULLE_USER_PWD}/"}\" and \"${logfile2#"${MULLE_USER_PWD}/"}\""
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
      PATH="${DEFINITION_PATH:-${PATH}}"
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
                            "'${kitchendir}'" \
                            "'${projectdir}'" | ${grepper}
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

   [ $# -eq 3 ] || _internal_fail "api error"

   local srcdir="$1"
   local definition="$2"
   local definitiondirs="$3"

   local projectfile
   local projectdir

   RVAL=""
   if ! make::common::r_find_nearest_matching_pattern "${srcdir}" "meson.build"
   then
      log_fluff "${srcdir#"${MULLE_USER_PWD}/"}: There was no meson.build file found"
      return 1
   fi
   projectfile="${RVAL}"

   if [ ! -z "${OPTION_PHASE}" ]
   then
      fail "${srcdir#"${MULLE_USER_PWD}/"}: meson does not support build phases"
   fi

   make::plugin::meson::tools_environment

   if [ -z "${MESON}" ]
   then
      _log_warning "${srcdir#"${MULLE_USER_PWD}/"}: Found a meson.build, but \
${C_RESET}${C_BOLD}meson${C_WARNING} is not installed"
      return 1
   fi

   if [ -z "${MESON_BACKEND}" ]
   then
      fail "${srcdir#"${MULLE_USER_PWD}/"}: No meson backend available"
   fi

   log_verbose "Found meson project \"${projectfile#"${MULLE_USER_PWD}/"}\""

   RVAL="${projectfile}"

   return 0
}


make::plugin::meson::initialize()
{
   log_entry "make::plugin::meson::initialize"

   include "string"
   include "path"
   include "file"
}

make::plugin::meson::initialize

:

