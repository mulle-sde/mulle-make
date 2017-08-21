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
MULLE_BOOTSTRAP_BUILD_PLUGIN_CONFIGURE_SH="included"


#
# remove old builddir, create a new one
# depending on configuration cmake with flags
# build stuff into dependencies
#
#
build_configure()
{
   log_entry "build_configure" "$@"

   local projectfile="$1"
   local configuration="$2"
   local srcdir="$3"
   local builddir="$4"
   local name="$5"
   local sdk="$6"

   local projectdir

   projectdir="`dirname -- "${projectfile}"`"

   local configure_flags

   configure_flags="`read_build_setting "${name}" "configure_flags"`"

#   create_dummy_dirs_against_warnings "${mapped}" "${suffix}"

   local c_compiler_line
   local cxx_compiler_line

   if [ ! -z "${C_COMPILER}" ]
   then
      c_compiler_line="CC='${C_COMPILER}'"
   fi
   if [ ! -z "${CXX_COMPILER}" ]
   then
      cxx_compiler_line="CXX='${CXX_COMPILER}'"
   fi

   mkdir_if_missing "${builddir}"

   local other_cflags
   local other_cxxflags
   local other_cppflags
   local other_ldflags

   other_cflags="`gcc_cflags_value "${name}"`"
   other_cxxflags="`gcc_cxxflags_value "${name}"`"
   other_cppflags="`gcc_cppflags_value "${name}"`"
   other_ldflags="`gcc_ldflags_value "${name}"`"

   local flaglines
   local mapped

   mapped="`read_build_setting "${name}" "cmake-${configuration}.map" "${configuration}"`"
   flaglines="`build_unix_flags "$@" "${mapped}"`"

   local cppflags
   local ldflags
   local dependenciesdir

   cppflags="`echo "${flaglines}" | sed -n '1p'`"
   ldflags="`echo "${flaglines}"  | sed -n '2p'`"
   dependenciesdir="`echo "${flaglines}"  | sed -n '9p'`"

   local addictionsdir
   local binpath

   addictionsdir="${nativewd}/${REFERENCE_ADDICTIONS_DIR}"
   binpath="${dependenciesdir}/bin"

   # CMAKE_CPP_FLAGS does not exist in cmake
   # so merge into CFLAGS and CXXFLAGS

   if [ -z "${cppflags}" ]
   then
      other_cppflags="`concat "${other_cppflags}" "${cppflags}"`"
   fi

   if [ -z "${ldflags}" ]
   then
      other_ldflags="`concat "${other_ldflags}" "${ldflags}"`"
   fi

   local sdkpath

   sdkpath="`gcc_sdk_parameter "${sdk}"`"
   sdkpath="`echo "${sdkpath}" | sed -e 's/ /\\ /g'`"

   if [ ! -z "${sdkpath}" ]
   then
      other_cppflags="`concat "-isysroot ${sdkpath}" "${other_cppflags}"`"
      other_ldflags="`concat "-isysroot ${sdkpath}" "${other_ldflags}"`"
   fi

   local env_flags

   if [ ! -z "${other_cppflags}" ]
   then
      env_flags="`concat "${cmake_flags}" "CPPFLAGS='${other_cppflags}'"`"
   fi
   if [ ! -z "${other_cflags}" ]
   then
      env_flags="`concat "${cmake_flags}" "CFLAGS='${other_cflags}'"`"
   fi
   if [ ! -z "${other_cxxflags}" ]
   then
      env_flags="`concat "${cmake_flags}" "CXXFLAGS='${other_cxxflags}'"`"
   fi
   if [ ! -z "${other_ldflags}" ]
   then
      env_flags="`concat "${cmake_flags}" "LDFLAGS='${other_ldflags}'"`"
   fi

   local logfile1
   local logfile2

   mkdir_if_missing "${BUILDLOGS_DIR}"

   logfile1="`build_log_name "configure" "${name}" "${configuration}" "${sdk}"`"
   logfile2="`build_log_name "make" "${name}" "${configuration}" "${sdk}"`"

   (
      local owd
      local nativewd

      owd="${PWD}"
      nativewd="`pwd ${BUILD_PWD_OPTIONS}`"

      exekutor cd "${builddir}" || fail "failed to enter ${builddir}"

      # DONT READ CONFIG SETTING IN THIS INDENT
      set -f

      if [ "$MULLE_FLAG_VERBOSE_BUILD" = "YES" ]
      then
         logfile1="`tty`"
         logfile2="$logfile1"
      fi
      if [ "$MULLE_FLAG_EXEKUTOR_DRY_RUN" = "YES" ]
      then
         logfile1="/dev/null"
         logfile2="/dev/null"
      fi

      log_verbose "Build logs will be in \"${logfile1}\" and \"${logfile2}\""

      local prefixbuild

      prefixbuild="`add_component "${prefixbuild}" "${nativewd}/${BUILD_DEPENDENCIES_DIR}"`"

      local oldpath
      local rval

      oldpath="$PATH"
      PATH="${binpath}:${BUILDPATH}"

      log_fluff "PATH temporarily set to $PATH"

       # use absolute paths for configure, safer (and easier to read IMO)
      logging_redirect_eval_exekutor "${logfile1}" \
         DEPENDENCIES_DIR="'${dependenciesdir}'" \
         ADDICTIONS_DIR="'${addictionsdir}'" \
         "${c_compiler_line}" \
         "${cxx_compiler_line}" \
         "${env_flags}" \
         "'${owd}/${projectdir}/configure'" \
         "${configure_flags}" \
         --prefix "'${prefixbuild}'"
      rval=$?

      if [ $rval -ne 0 ]
      then
         PATH="${oldpath}"
         build_fail "${logfile1}" "configure"
      fi

      logging_redirekt_exekutor "${logfile2}" "${MAKE}" ${MAKE_FLAGS} install
      rval=$?

      PATH="${oldpath}"
      [ $rval -ne 0 ] && build_fail "${logfile2}" "make"

      set +f

   ) || exit 1
}


test_configure()
{
   log_entry "test_configure" "$@"

   local configuration="$1"
   local srcdir="$2"
   local builddir="$3"
   local name="$4"

   local projectfile
   local projectdir

   projectfile="`find_nearest_matching_pattern "${srcdir}" "configure"`"
   if [ -z "${projectfile}" ]
   then
      log_fluff "There is no configure project in \"${srcdir}\""
      return 1
   fi
   projectfile="${srcdir}/${projectfile}"
   projectdir="`dirname -- "${projectfile}"`"

   if ! [ -x "${projectdir}/configure" ]
   then
      log_fluff "Configure script in \"${projectdir}\" is not executable"
      return 1
   fi

   tools_environment_make "${name}" "${projectdir}"

   if [ -z "${MAKE}" ]
   then
      log_warning "Found a ./configure, but ${C_RESET}${C_BOLD}make${C_WARNING} is not installed"
      return 1
   fi

   PROJECTFILE="${projectfile}"
   return 0
}
