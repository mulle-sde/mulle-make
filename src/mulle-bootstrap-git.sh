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
MULLE_BOOTSTRAP_GIT_SH="included"

#
# prefer origin over others, probably could be smarter
# by passing in the desired branch and figuring more
# stuff out
#
git_get_default_remote()
{
   local i
   local match

   match=""
   IFS="
"
   for i in `( cd "$1" ; git remote)`
   do
      case "$i" in
         origin)
            match="$i"
            break
         ;;

         *)
            if [ -z "${match}" ]
            then
               match="$i"
            fi
         ;;
      esac
   done

   IFS="${DEFAULT_IFS}"

   echo "$match"
}


git_has_branch()
{
   (
      cd "$1" &&
      git branch | cut -c3- | fgrep -q -s -x "$2" > /dev/null
   ) || exit 1
}


git_get_branch()
{
   (
      cd "$1" &&
      git rev-parse --abbrev-ref HEAD 2> /dev/null
   ) || exit 1
}


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



git_enable_mirroring()
{
   local allow_refresh="${1:-YES}"

   #
   # stuff clones get intermediate saved too, default is on
   # this is only called in main if the option is yes
   #
   GIT_MIRROR="`read_config_setting "git_mirror"`"
   if [ "${allow_refresh}" = "YES" ]
   then
      REFRESH_GIT_MIRROR="`read_config_setting "refresh_git_mirror" "YES"`"
   fi
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


git_initialize()
{
   log_debug ":git_initialize:"

   [ -z "${MULLE_BOOTSTRAP_SCM_SH}" ] && . mulle-bootstrap-scm.sh

   # this is an actual GIT variable
   GIT_TERMINAL_PROMPT="`read_config_setting "git_terminal_prompt" "0"`"
   export GIT_TERMINAL_PROMPT
}


git_initialize

: