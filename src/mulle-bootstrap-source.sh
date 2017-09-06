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
#
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
#
MULLE_BOOTSTRAP_SOURCE_SH="included"


find_single_directory_in_directory()
{
   local count
   local filename

   filename="`ls -1 "${tmpdir}"`"

   count="`echo "$filename}" | wc -l`"
   if [ $count -ne 1 ]
   then
      return
   fi

   echo "${tmpdir}/${filename}"
}


archive_move_stuff()
{
   log_entry "archive_move_stuff" "$@"

   local tmpdir="$1"
   local stashdir="$2"
   local archivename="$3"
   local name="$4"

   local src
   local toremove

   toremove="${tmpdir}"

   src="${tmpdir}/${archivename}"
   if [ ! -d "${src}" ]
   then
      src="${tmpdir}/${name}"
      if [ ! -d "${src}" ]
      then
         src="`find_single_directory_in_directory "${tmpdir}"`"
         if [ -z "${src}" ]
         then
            src="${tmpdir}"
            toremove=""
         fi
      fi
   fi

   exekutor mv "${src}" "${stashdir}"

   if [ ! -z "${toremove}" ]
   then
      rmdir_safer "${toremove}"
   fi
}


_archive_search_local()
{
   log_entry "_archive_search_local" "$@"

   local directory="$1"
   local name="$2"
   local filename="$3"

   [ $# -ne 3 ] && internal_fail "fail"

   local found

   found="${directory}/${name}-${filename}"
   log_fluff "Looking for \"${found}\""
   if [ -f "${found}" ]
   then
      log_fluff "Found \"${name}\" in \"${directory}\" as \"${found}\""

      echo "${found}"
      return
   fi

   found="${directory}/${filename}"
   log_fluff "Looking for \"${found}\""
   if [ -f "${found}" ]
   then
      log_fluff "Found \"${name}\" in \"${directory}\" as \"${found}\""

      echo "${found}"
      return
   fi
}


archive_search_local()
{
   log_entry "archive_search_local" "$@"

   local url="$1"
   local name="$2"
#   local branch="$3"

   local filename

   filename="`basename -- "${url}"`"

   local found
   local directory

   IFS=":"
   for directory in ${LOCAL_PATH}
   do
      IFS="${DEFAULT_IFS}"

      found="`_archive_search_local "${directory}" "${name}" "${filename}"`" || exit 1
      if [ ! -z "${found}" ]
      then
         found="`absolutepath "${found}"`"
         echo "file:///${found}"
         return 0
      fi
   done

   IFS="${DEFAULT_IFS}"
   return 1
}


validate_shasum256()
{
   log_entry "validate_shasum256" "$@"

   local filename="$1"
   local expected="$2"

   case "${UNAME}" in
      mingw)
         log_fluff "mingw does not support shasum" # or does it ?
         return
      ;;
   esac


   local checksum

   checksum="`shasum -a 256 -p "${filename}" | awk '{ print $1 }'`"
   if [ "${expected}" != "${checksum}" ]
   then
      log_error "${filename} sha256 is ${checksum}, not ${expected} as expected"
      return 1
   fi
   log_fluff "shasum256 did validate \"${filename}\""
}


validate_download()
{
   log_entry "validate_download" "$@"

   local filename="$1"
   local sourceoptions="$2"

   local checksum
   local expected

   expected="`get_sourceoption "$sourceoptions" "shasum256"`"
   if [ -z "${expected}" ]
   then
      return
   fi

   validate_shasum256 "${filename}" "${expected}"
}


#
# prints each key=value on a line so that its greppable
# TODO: Doesn't do escaping yet
#
parse_sourceoptions()
{
   log_entry "parse_sourceoptions" "$@"

   local sourceoptions="$1"

   local key
   local value

   while [ ! -z "${sourceoptions}" ]
   do
      # ignore single comma
      case "${sourceoptions}" in
         ,*)
            sourceoptions="${sourceoptions#,}"
            continue
         ;;
      esac

      key="`sed -n 's/^\([a-zA-Z_][a-zA-Z0-9_]*\)=.*/\1/p' <<< "${sourceoptions}"`"
      if [ -z "${key}" ]
      then
         fail "Unparsable sourceoption \"${sourceoptions}\""
         exit 1
      fi
      sourceoptions="${sourceoptions#${key}=}"

      value="`sed -n 's/\([^,]*\),.*/\1/p' <<< "${sourceoptions}"`"
      if [ -z "${value}" ]
      then
         value="${sourceoptions}"
         sourceoptions=""
      else
         sourceoptions="${sourceoptions#${value},}"
      fi

      echo "${key}=${value}"
   done
}


get_sourceoption()
{
   local sourceoptions="$1"
   local key="$2"

   sed -n "s/^${key}="'\(.*\)/\1/p' <<< "${sourceoptions}"
}


get_source_function()
{
   log_entry "get_source_function" "$@"

   local source="$1"
   local opname="$2"

   local operation

   operation="${source}_${opname}_project"
   if [ "`type -t "${operation}"`" = "function" ]
   then
      echo "${operation}"
   else
      log_fluff "Plugin function \"${operation}\" is not available"
   fi
}


source_search_local()
{
   log_entry "source_search_local" "$@"

   local name="$1"
   local branch="$2"
   local extension="$3"
   local need_extension="$4"
   local directory="$5"

   local found

   if [ "${MULLE_FLAG_LOG_LOCALS}" = "YES" ]
   then
      log_trace "Checking local path \"${directory}\""
   fi

   if [ ! -z "${branch}" ]
   then
      found="${directory}/${name}.${branch}${extension}"
      log_fluff "Looking for \"${found}\""

      if [ -d "${found}" ]
      then
         log_fluff "Found \"${name}.${branch}${extension}\" in \"${directory}\""

         echo "${found}"
         return
      fi
   fi

   found="${directory}/${name}${extension}"
   log_fluff "Looking for \"${found}\""
   if [ -d "${found}" ]
   then
      log_fluff "Found \"${name}${extension}\" in \"${directory}\""

      echo "${found}"
      return
   fi

   if [ "${need_extension}" != "YES" ]
   then
      found="${directory}/${name}"
      log_fluff "Looking for \"${found}\""
      if [ -d "${found}" ]
      then
         log_fluff "Found \"${name}\" in \"${directory}\""

         echo "${found}"
         return
      fi
   fi
}


source_search_local_path()
{
   log_entry "source_search_local_path [${LOCAL_PATH}]" "$@"

   local name="$1"
   local branch="$2"
   local extension="$3"
   local required="$4"

   local found
   local directory
   local realdir
   local curdir

   if [ "${MULLE_FLAG_LOG_LOCAL}" = "YES" -a -z "${LOCAL_PATH}" ]
   then
      log_trace "LOCAL_PATH is empty"
   fi

   curdir="`pwd -P`"
   IFS=":"
   for directory in ${LOCAL_PATH}
   do
      IFS="${DEFAULT_IFS}"

      if [ ! -d "${directory}" ]
      then
         if [ "${MULLE_FLAG_LOG_LOCALS}" = "YES" ]
         then
            log_trace2 "Local path \"${realdir}\" does not exist"
         fi
         continue
      fi

      realdir="`realpath "${directory}"`"
      if [ "${realdir}" = "${curdir}" ]
      then
         fail "Config setting \"search_path\" mistakenly contains \"${directory}\", which is the current directory"
      fi

      found="`source_search_local "$@" "${realdir}"`"
      if [ ! -z "${found}" ]
      then
         echo "${found}"
         return
      fi
   done

   IFS="${DEFAULT_IFS}"
   return 1
}



source_operation()
{
   log_entry "source_operation" "$@"

   local opname="$1" ; shift

   local reposdir="$1"     # ususally .bootstrap.repos
   local name="$2"         # name of the clone
   local url="$3"          # URL of the clone
   local branch="$4"       # branch of the clone
   local tag="$5"          # tag to checkout of the clone
   local source="$6"          # source to use for this clone
   local sourceoptions="$7"   # options to use on source
   local stashdir="$8"     # stashdir of this clone (absolute or relative to $PWD)

   local operation

   operation="`get_source_function "${source}" "${opname}"`"
   if [ -z "${operation}" ]
   then
      return 111
   fi

   local parsed_sourceoptions

   parsed_sourceoptions="`parse_sourceoptions "${sourceoptions}"`"

   "${operation}" "${reposdir}" \
                  "${name}" \
                  "${url}" \
                  "${branch}" \
                  "${tag}" \
                  "${source}" \
                  "${parsed_sourceoptions}" \
                  "${stashdir}"
}


load_source_plugins()
{
   log_entry "load_source_plugins"

   local upcase
   local plugindefine
   local pluginpath
   local name

   log_fluff "Loading source plugins..."

   IFS="
"
   for pluginpath in `ls -1 "${MULLE_BOOTSTRAP_LIBEXEC_PATH}/mulle-bootstrap-source-plugins/"*.sh`
   do
      IFS="${DEFAULT_IFS}"

      name="`basename -- "${pluginpath}" .sh`"

      # don't load xcodebuild on non macos platforms
      case "${UNAME}" in
         darwin)
         ;;

         *)
            case "${name}" in
               xcodebuild)
                  continue
               ;;
            esac
         ;;
      esac

      upcase="`tr 'a-z' 'A-Z' <<< "${name}"`"
      plugindefine="MULLE_BOOTSTRAP_SOURCE_PLUGIN_${upcase}_SH"

      if [ -z "`eval echo \$\{${plugindefine}\}`" ]
      then
         . "${pluginpath}"

         if [ "`type -t "${name}_clone_project"`" != "function" ]
         then
            fail "Source plugin \"${pluginpath}\" has no \"${name}_clone_project\" function"
         fi

         log_fluff "Source plugin \"${name}\" loaded"
      fi
   done

   IFS="${DEFAULT_IFS}"
}


source_initialize()
{
   log_debug ":source_initialize:"

   [ -z "${MULLE_BOOTSTRAP_FUNCTIONS_SH}" ]    && . mulle-bootstrap-functions.sh
   [ -z "${MULLE_BOOTSTRAP_REPOSITORIES_SH}" ] && . mulle-bootstrap-repositories.sh

   load_source_plugins
}

source_initialize

: