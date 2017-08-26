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


append_dir_to_gitignore_if_needed()
{
   local directory=$1

   [ -z "${directory}" ] && internal_fail "empty directory"

   case "${directory}" in
      "${REPOS_DIR}/"*)
         return 0
      ;;
   esac

   # strip slashes
   case "${directory}" in
      /*/)
         directory="`echo "$1" | sed 's/.$//' | sed 's/^.//'`"
      ;;

      /*)
         directory="`echo "$1" | sed 's/^.//'`"
      ;;

      */)
         directory="`echo "/$1" | sed 's/.$//'`"
      ;;

      *)
         directory="$1"
      ;;
   esac

   #
   # prepend \n because it is safer, in case .gitignore has no trailing
   # LF which it often seems to not have
   # fgrep is bugged on at least OS X 10.x, so can't use -e chaining
   if [ -f ".gitignore" ]
   then
      local pattern0
      local pattern1
      local pattern2
      local pattern3


      # variations with leadinf and trailing slashes
      pattern0="${directory}"
      pattern1="${pattern0}/"
      pattern2="/${pattern0}"
      pattern3="/${pattern0}/"

      if fgrep -q -s -x -e "${pattern0}" .gitignore ||
         fgrep -q -s -x -e "${pattern1}" .gitignore ||
         fgrep -q -s -x -e "${pattern2}" .gitignore ||
         fgrep -q -s -x -e "${pattern3}" .gitignore
      then
         return
      fi
   fi

   local line
   local lf
   local terminator

   line="/${directory}"
   terminator="`tail -c 1 ".gitignore" 2> /dev/null | tr '\012' '|'`"

   if [ "${terminator}" != "|" ]
   then
      line="${lf}/${directory}"
   fi

   log_info "Adding \"/${directory}\" to \".gitignore\""
   redirect_append_exekutor .gitignore echo "${line}" || fail "Couldn\'t append to .gitignore"
}


fork_and_name_from_url()
{
   local url="$1"
   local name
   local hack
   local fork

   hack="`sed 's|^[^:]*:|:|' <<< "${url}"`"
   name="`basename -- "${hack}"`"
   fork="`dirname -- "${hack}"`"
   fork="`basename -- "${fork}"`"

   case "${hack}" in
      /*/*|:[^/]*/*|://*/*/*)
      ;;

      *)
         fork="__other__"
      ;;
   esac

   echo "${fork}" | sed 's|^:||'
   echo "${name}"
}


git_is_repository()
{
   [ -d "${1}/.git" ] || [ -d  "${1}/refs" -a -f "${1}/HEAD" ]
}


git_is_bare_repository()
{
   local is_bare

   # if bare repo, we can only clone anyway
   is_bare=`(
               cd "$1" &&
               git rev-parse --is-bare-repository 2> /dev/null
            )` || internal_fail "wrong \"$1\" for \"`pwd`\""
   [ "${is_bare}" = "true" ]
}


#
# will this run over embedded too ?
#
_run_git_on_stash()
{
   local i="$1" ; shift

   if [ -d "${i}/.git" -o -d "${i}/refs" ]
   then
      log_info "### $i:"
      (
         cd "$i" ;
         exekutor git ${GITFLAGS} "$@" ${GITOPTIONS}  >&2
      ) || fail "git failed"
      log_info
   fi
}


#
# todo: let user select what repositories are affected
#
run_git()
{
   local i

   IFS="
"
   for i in `all_repository_stashes`
   do
      IFS="${DEFAULT_IFS}"

      _run_git_on_stash "$i" "$@"
   done

   for i in `all_embedded_repository_stashes`
   do
      IFS="${DEFAULT_IFS}"

      _run_git_on_stash "$i" "$@"
   done

   for i in `all_deep_embedded_repository_stashes`
   do
      IFS="${DEFAULT_IFS}"

      _run_git_on_stash "$i" "$@"
   done

   IFS="${DEFAULT_IFS}"
}


git_main()
{
   log_debug "::: git :::"

   [ -z "${MULLE_BOOTSTRAP_LOCAL_ENVIRONMENT_SH}" ] && . mulle-bootstrap-local-environment.sh
   [ -z "${MULLE_BOOTSTRAP_SCRIPTS_SH}" ]           && . mulle-bootstrap-scripts.sh

   while :
   do
      if [ "$1" = "-h" -o "$1" = "--help" ]
      then
         git_usage
      fi

      break
   done

   if dir_has_files "${REPOS_DIR}"
   then
      log_fluff "Will run \"git $*\" over clones" >&2
   else
      log_verbose "There is nothing to run git over."
      return 0
   fi

   run_git "$@"
}


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
   log_entry "_tar_search_local" "$@"

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