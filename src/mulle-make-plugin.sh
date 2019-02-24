#! /usr/bin/env bash
#
#   Copyright (c) 2015-2017 Nat! - Mulle kybernetiK
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
MULLE_MAKE_PLUGIN_SH="included"


build_list_plugins()
{
   log_entry "build_list_plugins"

   log_fluff "Listing build plugins..."

   local pluginpath
   local pluginname
   IFS=$'\n'
   for pluginpath in `exekutor ls -1 "${MULLE_MAKE_LIBEXEC_DIR}/plugins/"*.sh`
   do
      r_extensionless_basename "${pluginpath}"
      pluginname="${RVAL}"

      # don't load xcodebuild on non macos platforms
      case "${MULLE_UNAME}" in
         darwin)
         ;;

         *)
            case "${pluginname}" in
               xcodebuild)
                  continue
               ;;
            esac
         ;;
      esac

      echo "${pluginname}"
   done

   IFS="${DEFAULT_IFS}"
}


build_load_plugin()
{
   local preference="$1"

   local upcase
   local plugindefine
   local pluginpath

   if [ "`type -t "r_test_${preference}"`" = "function" ]
   then
      log_debug "Plugin \"${preference}\" already loaded"
      return 0
   fi

#
# doppelt gemoppelt
#
#   upcase="`tr 'a-z' 'A-Z' <<< "${preference}"`"
#   plugindefine="MULLE_MAKE_PLUGIN_${upcase}_SH"

#   if [ -z "`eval echo \$\{${plugindefine}\}`" ]
#   then
      pluginpath="${MULLE_MAKE_LIBEXEC_DIR}/plugins/${preference}.sh"
      if [ ! -f "${pluginpath}" ]
      then
         log_warning "No mulle-make plugin for \"${preference}\" found"
         return 1
      fi

      . "${pluginpath}" > /dev/null 2>&1

      #
      # too costly normally
      #
      if [ "${MULLE_FLAG_LOG_VERBOSE}"  = 'YES' ]
      then
         if [ "`type -t "r_test_${preference}"`" != "function" ]
         then
            internal_fail "Build plugin \"${pluginpath}\" has no \"r_test_${preference}\" function"
         fi

         if [ "`type -t "build_${preference}"`" != "function" ]
         then
            internal_fail "Build plugin \"${pluginpath}\" has no \"build_${preference}\" function"
         fi
      fi

      log_debug "Build plugin for \"${preference}\" loaded"
#   fi

   return 0
}


build_load_plugins()
{
   log_entry "build_load_plugins" "$@"

   local preferences="$1"

   local preference
   AVAILABLE_PLUGINS=
   IFS=":"; set -o noglob
   for preference in ${preferences}
   do
      IFS="${DEFAULT_IFS}"; set +o noglob

      if ! build_load_plugin "${preference}"
      then
         continue
      fi
      r_add_line "${AVAILABLE_PLUGINS}" "${preference}"
      AVAILABLE_PLUGINS="${RVAL}"
   done

   IFS="${DEFAULT_IFS}"; set +o noglob
}

:
