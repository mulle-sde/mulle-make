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
make::plugin::make::build()
{
   log_entry "make::plugin::make::build" "$@"

   [ $# -ge 9 ] || _internal_fail "api error"

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

   # need this now
   mkdir_if_missing "${kitchendir}"

#   create_dummy_dirs_against_warnings "${mapped}" "${suffix}"

   # all these values are meant for 'eval', i.e. they are already
   # expansion protected
   local _c_compiler
   local _cxx_compiler
   local _cppflags
   local _cflags
   local _cxxflags
   local _ldflags
   local _pkgconfigpath

   make::common::_std_flags "${sdk}" "${platform}" "${configuration}"

   local c_compiler="${_c_compiler}"
   local cxx_compiler="${_cxx_compiler}"
   local cppflags="${_cppflags}"
   local cflags="${_cflags}"
   local cxxflags="${_cxxflags}"
   local ldflags="${_ldflags}"
   local pkgconfigpath="${_pkgconfigpath}"

   local arguments

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

   make::common::r_env_std_flags "${c_compiler}" \
                                 "${cxx_compiler}" \
                                 "${cppflags}" \
                                 "${cflags}" \
                                 "${cxxflags}" \
                                 "${ldflags}" \
                                 "${pkgconfigpath}"

   env_flags="${RVAL}"


   make::common::r_build_make_flags "${MAKE}" "${DEFINITION_MAKEFLAGS}"
   r_concat "${arguments}" "${RVAL}"
   arguments="${RVAL}"

   # plus-settings don't work for make
   local other_buildsettings

   other_buildsettings="`make::definition::emit_userdefined "-D" "=" "=" "" "'"`"
   r_concat "${arguments}" "${other_buildsettings}"
   arguments="${RVAL}"

   local maketarget

   make::common::r_maketarget "${cmd}" "${DEFINITION_TARGETS}"
   maketarget="${RVAL}"

   local _absprojectdir
   local _projectdir

   make::common::_project_directories "${projectfile}"

   local absprojectdir="${_absprojectdir}"
   local projectdir="${_projectdir}"

   log_setting "maketarget:      ${maketarget}"
   log_setting "MAKEFLAGS:       ${MAKEFLAGS}"
   log_setting "arguments:       ${arguments}"

   local logfile1

   mkdir_if_missing "${logsdir}"

   make::common::r_build_log_name "${logsdir}" "make"
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
      greplog="NO"
   fi

   mkdir_if_missing "${kitchendir}"

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

      PATH="${OPTION_PATH:-${PATH}}"
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
            make::common::build_fail "${logfile1}" "make" "${PIPESTATUS[ 0]}" "${greplog}"
         fi
      fi

      if ! logging_tee_eval_exekutor "${logfile1}" "${teefile1}" \
               "'${MAKE}'" "${MAKEFLAGS}" "${arguments}" "${maketarget}" | ${grepper}
      then
         make::common::build_fail "${logfile1}" "make" "${PIPESTATUS[ 0]}" "${greplog}"
      fi

   ) || exit 1
}


make::plugin::make::r_test()
{
   log_entry "make::plugin::make::r_test" "$@"

   [ $# -eq 3 ] || _internal_fail "api error"

   local srcdir="$1"
   local definition="$2"
   local definitiondirs="$3"

   local projectfile
   local projectdir

   if ! make::common::r_find_nearest_matching_pattern "${srcdir}" "Makefile"
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
      fail "${srcdir#"${MULLE_USER_PWD}/"}: Make does not support build phases
${C_INFO}This is probably a misconfiguration in your sourcetree. Suggest:
${C_RESET_BOLD}mulle-sde dependency mark <name> singlephase"
   fi

   case "${MULLE_UNAME}" in
      mingw*)#
         include "platform::mingw"
         platform::mingw::setup_buildenvironment
      ;;
   esac

   make::common::r_make_for_plugin "make" "no-ninja"
   MAKE="${RVAL}"

   make::common::tools_environment

   log_verbose "Found makefile script \"${projectfile#"${MULLE_USER_PWD}/"}\""

   RVAL="${projectfile}"
   return 0
}


make::plugin::make::initialize()
{
   log_entry "make::plugin::make::initialize"

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

make::plugin::make::initialize

:
