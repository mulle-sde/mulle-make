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
MULLE_MAKE_PLUGIN_CONFIGURE_SH='included'


#
# remove old kitchendir, create a new one
# depending on configuration cmake with flags
# build stuff into dependencies
#
#
make::plugin::configure::build()
{
   log_entry "make::plugin::configure::build" "$@"

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

   local configure_flags

   configure_flags="${DEFINITION_CONFIGUREFLAGS}"

   # need this now
   mkdir_if_missing "${kitchendir}"

#   create_dummy_dirs_against_warnings "${mapped}" "${suffix}"

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
   local cpp_flags="${_cppflags}"
   local c_flags="${_cflags}"
   local cxx_flags="${_cxxflags}"
   local ld_flags="${_ldflags}"
   local pkgconfigpath="${_pkgconfigpath}"

#
# cpp_flags should not be duplicated into CFLAGS and CXXFLAGS for configure.
# cmake has no CMAKE_CPP_FLAGS so we have to do it there

#
#   if [ ! -z "${cpp_flags}" ]
#   then
#      r_concat "${c_flags}" "${cpp_flags}"
#      c_flags="${RVAL}"
#
#      if [ "${DEFINITION_PROJECT_LANGUAGE}" != "c" ]
#      then
#         r_concat "${cxx_flags}" "${cpp_flags}"
#         cxx_flags="${RVAL}"
#      fi
#   fi

   local arguments
   local prefix

   prefix="${DEFINITION_PREFIX}"
   if [ ! -z "${prefix}" ]
   then
      arguments="--prefix${MULLE_MAKE_CONFIGURE_SPACE:-=}'${prefix}'"
   else
      if [ ! -z "${dstdir}" ]
      then
         arguments="--prefix${MULLE_MAKE_CONFIGURE_SPACE:-=}'${dstdir}'"
      fi
   fi
   
   case "${DEFINITION_LIBRARY_STYLE}" in
      standalone)
         fail "configure does not support standalone builds"
      ;;

      static)
         r_concat "${arguments}" --enable-static
         arguments="${RVAL}"
      ;;

      dynamic)
         r_concat "${arguments}" --enable-shared
         arguments="${RVAL}"
      ;;
   esac

   local maketarget

   make::common::r_maketarget "${cmd}" "${DEFINITION_TARGETS}"
   maketarget="${RVAL}"

   local env_flags

   make::common::r_env_std_flags "${c_compiler}" \
                                 "${cxx_compiler}" \
                                 "${cpp_flags}" \
                                 "${c_flags}" \
                                 "${cxx_flags}" \
                                 "${ld_flags}" \
                                 "${pkgconfigpath}"

   env_flags="${RVAL}"

   local make_flags

   make::common::r_build_make_flags "${MAKE}" "${DEFINITION_MAKEFLAGS}"
   make_flags="${RVAL}"

   local _absprojectdir
   local _projectdir

   make::common::__project_directories "${projectfile}"

   local absprojectdir="${_absprojectdir}"
   local projectdir="${_projectdir}"

   log_setting "prefix:          ${prefix}"
   log_setting "env_flags:       ${env_flags}"
   log_setting "make_flags:      ${make_flags}"
   log_setting "CONFIGUREFLAGS:  ${CONFIGUREFLAGS}"
   log_setting "configure_flags: ${configure_flags}"
   log_setting "arguments:       ${arguments}"

   local logfile1
   local logfile2

   mkdir_if_missing "${logsdir}"

   make::common::r_build_log_name "${logsdir}" "configure"
   logfile1="${RVAL}"
   make::common::r_build_log_name "${logsdir}" "make"
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
      teefile2="${logfile1}"
      grepper="make::common::log_delete_all"
      greplog='NO'
   fi

   (
      rexekutor cd "${kitchendir}" || fail "failed to enter ${kitchendir}"

      # redirecting exekutors operate in a subshell!
      logging_redirekt_exekutor "${logfile1}" \
         echo cd "${kitchendir}"

      PATH="${OPTION_PATH:-${PATH}}"
      PATH="${DEFINITION_PATH:-${PATH}}"
      log_fluff "PATH temporarily set to $PATH"
      if [ "${MULLE_FLAG_LOG_ENVIRONMENT}" = 'YES' ]
      then
         env | sort >&2
      fi

      # use absolute paths for configure, safer (and easier to read IMO)
      if ! logging_tee_eval_exekutor "${logfile1}" "${teefile1}" \
                                          "${env_flags}" \
                                             "'${absprojectdir}/configure'" \
                                                "${CONFIGUREFLAGS}" \
                                                "${configure_flags}" \
                                                "${arguments}" | ${grepper}
      then
         make::common::build_fail "${logfile1}" "configure" "${PIPESTATUS[ 0]}" "${greplog}"
      fi

      #
      # mainly for glibc, where it needs to do make all before make install.
      # could parameterize this as "DEFINITION_MAKE_STEPS=all,install" or so
      #
      if [ "${maketarget}" = "install" ]
      then
         if ! logging_tee_eval_exekutor "${logfile2}"  "${teefile2}" \
                  "'${MAKE}'" "${MAKEFLAGS}" "${make_flags}" "all"  | ${grepper}
         then
            make::common::build_fail "${logfile2}" "make" "${PIPESTATUS[ 0]}" "${greplog}"
         fi
      fi

      local sudo

      # check if prefix needs sudo, if yes ask user
      if [ ! -z "${prefix}" ]
      then
         exekutor mkdir -p "${prefix}" 2> /dev/null
         if [ ! -w "${prefix}" ]
         then
            _log_info "Sudo is needed to install into \"${prefix#"${MULLE_USER_PWD}/"}\".
You might get asked for your password."
            sudo="sudo"
         fi
      fi

      if ! logging_tee_eval_exekutor "${logfile2}"  "${teefile2}" \
              "${sudo}" "'${MAKE}'" "${MAKEFLAGS}" "${make_flags}" "${maketarget}"  | ${grepper}
      then
         make::common::build_fail "${logfile2}" "make" "${PIPESTATUS[ 0]}" "${greplog}"
      fi

   ) || exit 1
}


make::plugin::configure::r_test()
{
   log_entry "make::plugin::configure::r_test" "$@"

   [ $# -eq 3 ] || _internal_fail "api error"

   local srcdir="$1"
   local definition="$2"
   local definitiondirs="$3"

   local projectfile
   local projectdir

   RVAL=""

   if ! make::common::r_find_nearest_matching_pattern "${srcdir}" "configure"
   then
      log_fluff "There is no configure project in \"${srcdir}\""
      return 4
   fi

   projectfile="${RVAL}"
   r_dirname "${projectfile}"
   projectdir="${RVAL}"

   if [ ! -z "${OPTION_PHASE}" ]
   then
      fail "${srcdir#"${MULLE_USER_PWD}/"}: configure does not support build phases
${C_INFO}This is probably a misconfiguration in your sourcetree. Suggest:
${C_RESET_BOLD}mulle-sde dependency mark <name> singlephase"
   fi

   if ! [ -x "${projectdir}/configure" ]
   then
      log_fluff "Configure script in \"${projectdir}\" is not executable"
      return 1
   fi

   case "${MULLE_UNAME}" in
      'mingw')
         include "platform::mingw"
         platform::mingw::setup_buildenvironment
      ;;
   esac

   make::common::r_make_for_plugin "configure" "no-ninja"
   MAKE="${RVAL}"

   make::common::tools_environment

   log_verbose "Found configure script \"${projectfile#"${MULLE_USER_PWD}/"}\""

   RVAL="${projectfile}"
   return 0
}


make::plugin::configure::initialize()
{
   log_entry "make::plugin::configure::initialize"

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

make::plugin::configure::initialize

:
