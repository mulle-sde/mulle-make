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
MULLE_BOOTSTRAP_BUILD_PLUGIN_SCRIPT_SH="included"



run_log_build_script()
{
   echo "$@"
   run_script "$@"
}


build_script()
{
   log_entry "build_script" "$@"

   local script="$1"
   local configuration="$2"
   local srcdir="$3"
   local builddir="$4"
   local name="$5"
   local sdk="$6"

   local project
   local schemename
   local targetname
   local logfile

   mkdir_if_missing "${BUILDLOGS_DIR}"

   logfile="${BUILDLOGS_DIR}/${name}-${configuration}-${sdk}.script.log"
   logfile="`absolutepath "${logfile}"`"

   local suffixsubdir
   local binpath

   suffixsubdir="`determine_dependencies_subdir "${configuration}" "${sdk}" "${OPTION_DISPENSE_STYLE}"`" || exit 1
   binpath="${PWD}/${REFERENCE_DEPENDENCIES_DIR}${suffixsubdir}/bin"

   log_fluff "Build log will be in: ${C_RESET_BOLD}${logfile}${C_INFO}"

   mkdir_if_missing "${builddir}"

   local owd

   owd=`pwd`
   exekutor cd "${srcdir}" || exit 1

      if [ "$MULLE_FLAG_VERBOSE_BUILD" = "YES" ]
      then
         logfile="`tty`"
      fi
      if [ "$MULLE_FLAG_EXEKUTOR_DRY_RUN" = "YES" ]
      then
         logfile="/dev/null"
      fi

      local oldpath
      local rval

      oldpath="${PATH}"
      PATH="${binpath}:${BUILDPATH}"

      log_fluff "PATH temporarily set to $PATH"

      run_log_build_script "${owd}/${script}" \
                           "${configuration}" \
                           "${owd}/${srcdir}" \
                           "${owd}/${builddir}" \
                           "${owd}/${BUILD_DEPENDENCIES_DIR}" \
                           "${name}" \
                           "${sdk}" > "${logfile}"
      rval=$?

      PATH="${oldpath}"
      [ $rval -ne 0 ] && build_fail "${logfile}" "build.sh"

   exekutor cd "${owd}"
}



test_script()
{
   log_entry "test_script" "$@"

   local configuration="$1"
   local srcdir="$2"
   local builddir="$3"
   local name="$4"

   local script

   script="`find_build_setting_file "${name}" "bin/build.sh"`"
   if [ ! -x "${script}" ]
   then
      [ ! -e "${script}" ] || fail "script ${script} is not executable"
      log_fluff "There is no build script in \"`build_setting_path "${name}" "bin/build.sh"`\""
      return 1
   fi

   PROJECTFILE="${script}"
   return 0
}
