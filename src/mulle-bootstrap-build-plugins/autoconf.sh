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
MULLE_BOOTSTRAP_BUILD_PLUGIN_AUTOCONF_SH="included"


find_autoconf()
{
   local name="$1"

   local toolname

   toolname=`read_build_setting "${name}" "autoconf" "autoconf"`
   verify_binary "${toolname}" "autoconf" "autoconf"
}


find_autoreconf()
{
   local name="$1"

   local toolname

   toolname=`read_build_setting "${name}" "autoreconf" "autoreconf"`
   verify_binary "${toolname}" "autoreconf" "autoreconf"
}


tools_environment_autoconf()
{
   local name="$1"
#   local projectdir="$2"

   tools_environment_make "$@"

   AUTOCONF="`find_autoconf "${name}"`"
   AUTORECONF="`find_autoreconf "${name}"`"
}


build_autoconf()
{
   log_entry "build_autoconf" "$@"

   local projectfile="$1"
   local configuration="$2"
   local srcdir="$3"
   local builddir="$4"
   local name="$5"
   local sdk="$6"

   local projectdir

   projectdir="`dirname -- "${projectfile}"`"

   local autoconf_flags
   local autoreconf_flags

   autoconf_flags="`read_build_setting "${name}" "autoconf_flags"`"
   autoreconf_flags="`read_build_setting "${name}" "autoreconf_flags" "-vif"`"

   mkdir_if_missing "${builddir}"

   local flaglines
   local mapped

   mapped="`read_build_setting "${name}" "autoconf-${configuration}.map" "${configuration}"`"
   flaglines="`build_unix_flags "$@" "${mapped}"`"

   local dependenciesdir

   dependenciesdir="`echo "${flaglines}"  | sed -n '9p'`"

   local binpath

   binpath="${dependenciesdir}/bin"

   # CMAKE_CPP_FLAGS does not exist in cmake
   # so merge into CFLAGS and CXXFLAGS

   local logfile1

   mkdir_if_missing "${BUILDLOGS_DIR}"

   logfile1="`build_log_name "autoreconf" "${name}" "${configuration}" "${sdk}"`"
   logfile2="`build_log_name "autoconf" "${name}" "${configuration}" "${sdk}"`"

   (
      local owd
      local nativewd

      owd="${PWD}"
      nativewd="`pwd ${BUILD_PWD_OPTIONS}`"

      exekutor cd "${projectdir}" || fail "failed to enter ${projectdir}"

      # DONT READ CONFIG SETTING IN THIS INDENT
      set -f

      if [ "$MULLE_FLAG_VERBOSE_BUILD" = "YES" ]
      then
         logfile1="`tty`"
         logfile2="`tty`"
      fi

      if [ "$MULLE_FLAG_EXEKUTOR_DRY_RUN" = "YES" ]
      then
         logfile1="/dev/null"
         logfile2="/dev/null"
      fi

      log_verbose "Build log will be in \"${logfile1}\""

      local oldpath
      local rval

      oldpath="$PATH"
      PATH="${binpath}:${BUILDPATH}"

      log_fluff "PATH temporarily set to $PATH"

      if ! [ -f "aclocal4.am" ]
      then
          # use absolute paths for configure, safer (and easier to read IMO)
         logging_redirect_eval_exekutor "${logfile1}" \
            "${AUTORECONF}" \
            "${autoreconf_flags}"
         rval=$?

         if [ $rval -ne 0 ]
         then
            PATH="${oldpath}"
            build_fail "${logfile1}" "autoreconf"
         fi
      fi

       # use absolute paths for configure, safer (and easier to read IMO)
      logging_redirect_eval_exekutor "${logfile2}" \
         "${AUTOCONF}" \
         "${autoconf_flags}"
      rval=$?

      if [ $rval -ne 0 ]
      then
         PATH="${oldpath}"
         build_fail "${logfile2}" "autoconf"
      fi

      set +f

   ) || exit 1


   local WASXCODE
   local PROJECTFILE
   local TOOLNAME
   local AUX_INFO

   # daisy chain configure onto it
   TOOLNAME=configure
   WASXCODE="NO"

   test_configure "${configuration}" "${srcdir}" "${builddir}" "${name}"
   if [ $? -ne 0 ]
   then
      fail "Could not run configure for \"${srcdir}"\"
   fi

   [ -z "${PROJECTFILE}" ] && internal_fail "test_configure did not set PROJECTFILE"
         #statements

   # memorize that we did the reconf step
   mkdir_if_missing "${REPOS_DIR}/.autoconf"
   exekutor touch "${REPOS_DIR}/.autoconf/${name}"

   log_info "Let ${C_RESET_BOLD}${TOOLNAME}${C_INFO} do a reconf of \
${C_MAGENTA}${C_BOLD}${name}${C_INFO} in \"${builddir}\" ..."

   build_configure "${PROJECTFILE}" "${configuration}" "${srcdir}" "${builddir}" "${name}" "${sdk}"
   if [ $? -ne 0 ]
   then
      internal_fail "build_configure should exit on failure and not return"
   fi
}


test_autoconf()
{
   log_entry "test_autoconf" "$@"

   local configuration="$1"
   local srcdir="$2"
   local builddir="$3"
   local name="$4"

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

   if [ "${REPOS_DIR}/.autoconf/${name}" -nt "${projectfile}" ]
   then
      log_verbose "Autoconf has already run once, skipping..."
      return 1
   fi

   projectdir="`dirname -- "${projectfile}"`"

   tools_environment_autoconf "${name}" "${projectdir}"

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
