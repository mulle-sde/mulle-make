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
platform_meson_backend()
{
   local makepath="$1"

   local toolname

   toolname="${OPTION_NINJA:-${NINJA:-ninja}}"
   verify_binary "${toolname}" "ninja" "ninja"
}


find_meson()
{
   local toolname

   toolname="${OPTION_MESON:-${MESON:-meson}}"
   verify_binary "${toolname}" "meson" "meson"
}


tools_environment_meson()
{
   tools_environment_make "" "meson"

   local defaultbackend

   defaultbackend="`platform_meson_backend "${NINJA}"`"
   MESON="`find_meson`"
   MESON_BACKEND="${OPTION_MESON_BACKEND:-${defaultbackend}}"
}


meson_sdk_parameter()
{
   local sdk="$1"

   local sdkpath

   case "${MULLE_UNAME}" in
      "darwin")
         sdkpath=`compiler_sdk_parameter "${sdk}"` || exit 1
         if [ ! -z "${sdkpath}" ]
         then
            log_fluff "Set meson sdk to \"${sdkpath}\""
            echo "-isysroot '${sdkpath}'"
         fi
      ;;
   esac
}


#
# remove old builddir, create a new one
# depending on configuration meson with flags
# build stuff into dependencies
# TODO: cache commandline in a file $ and emit instead of rebuilding it every time
#
build_meson()
{
   log_entry "build_meson" "$@"

   [ $# -eq 8 ] || internal_fail "api error"

   local cmd="$1"; shift
   local projectfile="$1"; shift
   local configuration="$1"; shift
   local srcdir="$1"; shift
   local dstdir="$1"; shift
   local builddir="$1"; shift
   local logsdir="$1"; shift
   local sdk="$1"; shift

   [ -z "${cmd}" ] && internal_fail "cmd is empty"
   [ -z "${projectfile}" ] && internal_fail "projectfile is empty"
   [ -z "${configuration}" ] && internal_fail "configuration is empty"
   [ -z "${srcdir}" ] && internal_fail "srcdir is empty"
   [ -z "${builddir}" ] && internal_fail "builddir is empty"
   [ -z "${logsdir}" ] && internal_fail "logsdir is empty"
   [ -z "${sdk}" ] && internal_fail "sdk is empty"

   # need this now
   mkdir_if_missing "${builddir}"

   local cflags
   local cxxflags
   local cppflags
   local ldflags

   cflags="`compiler_cflags_value "${OPTION_CC}" "${configuration}" "NO" `" || exit 1
   cxxflags="`compiler_cxxflags_value "${OPTION_CXX:-${OPTION_CC}}" "${configuration}" "NO" `" || exit 1
   cppflags="`compiler_cppflags_value "${OPTION_INCLUDE_PATH}" `"  || exit 1 # only meson does OPTION_INCLUDE_PATH here
   ldflags="`compiler_ldflags_value`" || exit 1

   __add_path_tool_flags

   local rel_project_dir
   local absbuilddir
   local absprojectdir
   local projectdir

   projectdir="`dirname -- "${projectfile}"`"
   absprojectdir="$(simplified_absolutepath "${projectdir}")"
   absbuilddir="$(simplified_absolutepath "${builddir}")"

   rel_project_dir="`projectdir_relative_to_builddir "${absbuilddir}" "${absprojectdir}"`"

   log_debug "projectfile:     ${projectfile}"
   log_debug "projectdir:      ${projectdir}"
   log_debug "absprojectdir:   ${absprojectdir}"
   log_debug "absbuilddir:     ${absbuilddir}"
   log_debug "rel_project_dir: ${rel_project_dir}"
   log_debug "PWD:             ${PWD}"

   local meson_flags
   local meson_env
   local passed_keys

   passed_keys=
   meson_env=
   meson_flags="${OPTION_MESONFLAGS}"

   local maketarget

   case "${cmd}" in
      build)
         maketarget=
         if [ ! -z "${OPTION_PREFIX}" ]
         then
            meson_flags="`concat "${meson_flags}" "--prefix '${OPTION_PREFIX}'"`"
         fi
      ;;

      install)
         [ -z "${dstdir}" ] && internal_fail "srcdir is empty"
         maketarget="install"
         meson_flags="`concat "${meson_flags}" "--prefix '${dstdir}'"`"
      ;;
   esac

   if [ ! -z "${configuration}" ]
   then
      configuration="$(tr 'A-Z' 'a-z' <<< "${configuration}" )"
      meson_flags="`concat "${meson_flags}" "--buildtype '${configuration}'"`"
   fi

   if [ ! -z "${OPTION_CC}" ]
   then
      meson_env="`concat "${meson_env}" "CC='${OPTION_CC}'"`"
      passed_keys="`colon_concat "${passed_keys}" "CC"`"
   fi

   if [ ! -z "${OPTION_CXX}" ]
   then
      meson_env="`concat "${meson_env}" "CXX='${OPTION_CXX}'"`"
      passed_keys="`colon_concat "${passed_keys}" "CXX"`"
   fi

   local sdkparameter

   sdkparameter="`meson_sdk_parameter "${sdk}"`" || exit 1

   if [ ! -z "${sdkparameter}" ]
   then
      cppflags="`concat "${cppflags}" "${sdkparameter}"`"
   fi

   if [ ! -z "${cppflags}" ]
   then
      meson_env="`concat "${meson_env}" "CPPFLAGS='${cppflags}'"`"
      passed_keys="`colon_concat "${passed_keys}" "CPPFLAGS"`"
   fi
   if [ ! -z "${cflags}" ]
   then
      meson_env="`concat "${meson_env}" "CFLAGS='${cflags}'"`"
      passed_keys="`colon_concat "${passed_keys}" "CFLAGS"`"
   fi
   if [ ! -z "${cxxflags}" ]
   then
      meson_env="`concat "${meson_env}" "CXXFLAGS='${cxxflags}'"`"
      passed_keys="`colon_concat "${passed_keys}" "CXXFLAGS"`"
   fi
   if [ ! -z "${ldflags}" ]
   then
      meson_env="`concat "${meson_env}" "LDFLAGS='${ldflags}'"`"
      passed_keys="`colon_concat "${passed_keys}" "LDFLAGS"`"
   fi

   # always pass at least a trailing :
   meson_env="`concat "${meson_env}" "__MULLE_MAKE_ENV_ARGS='${passed_keys}':"`"

   local ninja_flags

   ninja_flags="${OPTION_NINJAFLAGS}"

   if [ ! -z "${OPTION_CORES}" ]
   then
      ninja_flags="-j '${OPTION_CORES}'"
   fi

   if [ "${MULLE_FLAG_LOG_VERBOSE}" = "YES" ]
   then
      ninja_flags="`concat "${ninja_flags}" "-v"`"
   fi

   local other_buildsettings

   other_buildsettings="`emit_userdefined_definitions "-D " "=" "=" ""`"
   if [ ! -z "${other_buildsettings}" ]
   then
      meson_flags="`concat "${meson_flags}" "${other_buildsettings}"`"
   fi

   local env_common

   env_common="`mulle_make_env_flags`"

   local logfile1
   local logfile2

   mkdir_if_missing "${logsdir}"

   logfile1="`build_log_name "${logsdir}" "meson" "${srcdir}" "${configuration}" "${sdk}"`"
   logfile2="`build_log_name "${logsdir}" "ninja" "${srcdir}" "${configuration}" "${sdk}"`"

   if [ "$MULLE_FLAG_LOG_VERBOSE" = "YES" ]
   then
      logfile1="`safe_tty`"
      logfile2="$logfile1"
   fi
   if [ "$MULLE_FLAG_EXEKUTOR_DRY_RUN" = "YES" ]
   then
      logfile1="/dev/null"
      logfile2="/dev/null"
   fi
   log_verbose "Build logs will be in \"${logfile1}\" and \"${logfile2}\""

   (
      [ -z "${BUILDPATH}" ] && internal_fail "BUILDPATH not set"
      PATH="${BUILDPATH}"
      log_fluff "PATH temporarily set to $PATH"
      if [ "${MULLE_FLAG_LOG_ENVIRONMENT}" = "YES" ]
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
      if [ -e "${builddir}/meson-private" ]
      then
         rmdir_safer "${builddir}"
      fi

      if ! logging_redirect_eval_exekutor "${logfile1}" \
               "${env_common}" \
               "${meson_env}" \
               "'${MESON}'" --backend "'${MESON_BACKEND}'" \
                            "${meson_flags}" \
                            "'${builddir}'"
      then
         build_fail "${logfile1}" "meson"
      fi

      exekutor cd "${builddir}" || fail "failed to enter ${builddir}"

      if ! logging_redirect_eval_exekutor "${logfile2}" \
               "${env_common}" \
               "'${NINJA}'" "${ninja_flags}" ${maketarget}
      then
         build_fail "${logfile2}" "ninja"
      fi
   ) || exit 1
}


test_meson()
{
   log_entry "test_meson" "$@"

   [ $# -eq 2 ] || internal_fail "api error"

   local configuration="$1"
   local srcdir="$2"

   local projectfile
   local projectdir

   projectfile="`find_nearest_matching_pattern "${srcdir}" "meson.build"`"
   if [ ! -f "${projectfile}" ]
   then
      log_fluff "There is no meson.build file in \"${srcdir}\""
      return 1
   fi

   tools_environment_meson

   if [ -z "${MESON}" ]
   then
      log_warning "Found a meson.build, but ${C_RESET}${C_BOLD}meson${C_WARNING} is not installed"
      return 1
   fi

   if [ -z "${MESON_BACKEND}" ]
   then
      fail "No meson backend available"
   fi

   #
   # ugly hackage
   #
   NINJA="${MESON_BACKEND}"

   log_verbose "Found meson project file \"${projectfile}\""

   PROJECTFILE="${projectfile}"

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

