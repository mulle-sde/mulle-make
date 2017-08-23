#! /usr/bin/env bash
#
#   Copyright (c) 2017 Nat! - Mulle kybernetiK
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
MULLE_BOOTSTRAP_SCM_PLUGIN_GIT_SH="included"


_git_search_local()
{
   log_entry "_git_search_local" "$@"

   local directory="$1"
   local name="$2"
   local branch="$3"

   [ $# -ne 3 ] && internal_fail "fail"

   local found

   if [ "${MULLE_FLAG_LOG_LOCALS}" = "YES" ]
   then
      log_trace "Checking local path \"${directory}\""
   fi

   if [ ! -z "${branch}" ]
   then
      found="${directory}/${name}.${branch}"
      log_fluff "Looking for \"${found}\""

      if [ -d "${found}" ]
      then
         log_fluff "Found \"${name}.${branch}\" in \"${directory}\""

         echo "${found}"
         return
      fi
   fi

   found="${directory}/${name}.git"
   log_fluff "Looking for \"${found}\""
   if [ -d "${found}" ]
   then
      log_fluff "Found \"${name}.git\" in \"${directory}\""

      echo "${found}"
      return
   fi

   found="${directory}/${name}"
   log_fluff "Looking for \"${found}\""
   if [ -d "${found}" ]
   then
      log_fluff "Found \"${name}\" in \"${directory}\""

      echo "${found}"
      return
   fi
}


# global variable __GIT_MIRROR_URLS__ used to avoid refetching
# repos in one setting
#
_git_get_mirror_url()
{
   log_entry "_git_get_mirror_url" "$@"

   local url="$1"; shift

   local name
   local fork
   local result

   result="`fork_and_name_from_url "${url}"`"
   fork="`echo "${result}" | head -1`"
   name="`echo "${result}" | tail -1`"

   local mirrordir

   mkdir_if_missing "${GIT_MIRROR}/${fork}"
   mirrordir="${GIT_MIRROR}/${fork}/${name}" # try to keep it global

   local match
   local filelistpath

   # use global reposdir
   [ -z "${REPOS_DIR}" ] && internal_fail "REPOS_DIR undefined"

   filelistpath="${REPOS_DIR}/.uptodate-mirrors"
   log_debug "Mirror URLS: `cat "${filelistpath}" 2>/dev/null`"

   match="`fgrep -s -x "${mirrordir}" "${filelistpath}" 2>/dev/null`"
   if [ ! -z "${match}" ]
   then
      log_fluff "Repository \"${mirrordir}\" already up-to-date for this session"
      echo "${mirrordir}"
      return 0
   fi

   if [ ! -d "${mirrordir}" ]
   then
      log_verbose "Set up git-mirror \"${mirrordir}\""
      if ! exekutor git ${GITFLAGS} clone --mirror ${options} ${GITOPTIONS} -- "${url}" "${mirrordir}" >&2
      then
         log_error "git clone of \"${url}\" into \"${mirrordir}\" failed"
         return 1
      fi
   else
      # refetch

      if [ "${REFRESH_GIT_MIRROR}" = "YES" ]
      then
      (
         log_verbose "Refreshing git-mirror \"${mirrordir}\""
         cd "${mirrordir}";
         if ! exekutor git ${GITFLAGS} fetch >&2
         then
            log_warning "git fetch from \"${url}\" failed, using old state"
         fi
      )
      fi
   fi

   # for embedded we are otherwise too early
   echo "${mirrordir}" >> "${filelistpath}"
   echo "${mirrordir}"
}


_git_clone()
{
   log_entry "_git_clone" "$@"

   [ $# -lt 8 ] && internal_fail "parameters missing"

#   local reposdir="$1"
   local name="$2"
   local url="$3"
   local branch="$4"
#   local tag="$5"
#   local scm="$6"
   local scmoptions="$7"
   local stashdir="$8"

   [ ! -z "${url}" ]      || internal_fail "url is empty"
   [ ! -z "${stashdir}" ] || internal_fail "stashdir is empty"

   [ -e "${stashdir}" ]   && internal_fail "${stashdir} already exists"

   local options
   local dstdir

   dstdir="${stashdir}"
   options="`get_scmoption "${scmoptions}" "fetch"`"

   if [ ! -z "${branch}" ]
   then
      log_info "Cloning ${C_RESET_BOLD}$branch${C_INFO} of ${C_MAGENTA}${C_BOLD}${url}${C_INFO} into \"${stashdir}\" ..."
      options="-b ${branch}"
   else
      log_info "Cloning ${C_MAGENTA}${C_BOLD}${url}${C_INFO} into \"${stashdir}\" ..."
   fi

   local originalurl
   #
   # "remote urls" go through mirror
   # local urls get checked ahead for better error messages
   #
   case "${url}" in
      file:*)
         if ! git_is_repository "${url}"
         then
            log_error "\"${url}\" is not a git repository ($PWD)"
            return 1
         fi
      ;;

      *:*)
         if [ ! -z "${GIT_MIRROR}" ]
         then
            originalurl="${url}"
            url="`_git_get_mirror_url "${url}"`" || return 1
            options="`concat "--origin mirror" "${options}"`"
         fi
      ;;

      *)
         if ! git_is_repository "${url}"
         then
            log_error "\"${url}\" is not a git repository ($PWD)"
            return 1
         fi
      ;;
   esac

#
# callers responsibility
#
#   local parent
#
#    parent="`dirname -- "${stashdir}"`"
#   mkdir_if_missing "${parent}"

   if [ "${stashdir}" = "${url}" ]
   then
      # since we know that stash dir does not exist, this
      # message is a bit less confusing
      log_error "Clone source \"${url}\" does not exist."
      return 1
   fi

   if ! exekutor git ${GITFLAGS} "clone" ${options} ${GITOPTIONS} -- "${url}" "${stashdir}"  >&2
   then
      log_error "git clone of \"${url}\" into \"${stashdir}\" failed"
      return 1
   fi

   if [ ! -z "${originalurl}" ]
   then
      git_unset_default_remote "${stashdir}"
      git_add_remote "${stashdir}" "origin" "${originalurl}"

      #
      # too expensive for me, because it must fetch now to
      # get the origin branch. Funnily enough it works fine
      # even without it..
      #
      if read_yes_no_config_setting "git_set_default_remote"
      then
         git_set_default_remote "${stashdir}" "origin" "${branch}"
      fi
   fi
}


_get_fetch_remote()
{
   local url="$1"
   local remote

   remote="origin"

   # "remote urls" going through cache will be refreshed here
   case "${url}" in
      file:*|/*|~*|.*)
      ;;

      *:*)
         if [ ! -z "${GIT_MIRROR}" ]
         then

            _git_get_mirror_url "${url}" > /dev/null || return 1
            remote="mirror"
         fi
      ;;
   esac

   echo "${remote}"
}


###
### Plugin API
###

git_clone_project()
{
   log_entry "git_clone_project" "$@"

   if ! _git_clone "$@"
   then
      return 1
   fi

   if [ ! -z "${tag}" ]
   then
      git_checkout "$@"
   fi
}


git_checkout_project()
{
   log_entry "git_checkout_project" "$@"

   [ $# -lt 8 ] && internal_fail "parameters missing"

   local reposdir="$1" ; shift
   local name="$1"; shift
   local url="$1"; shift
   local branch="$1"; shift
   local tag="$1"; shift
   local scm="$1"; shift
   local scmoptions="$1"; shift
   local stashdir="$1"; shift

   [ -z "${stashdir}" ] && internal_fail "stashdir is empty"
   [ -z "${tag}" ]      && internal_fail "tag is empty"

   local options

   options="`get_scmoption "${scmoptions}" "checkout"`"

   local branch

   branch="`git_get_branch "${stashdir}"`"

   if [ "${branch}" != "${tag}" ]
   then
      log_info "Checking out version ${C_RESET_BOLD}${tag}${C_INFO} of ${C_MAGENTA}${C_BOLD}${stashdir}${C_INFO} ..."
      (
         exekutor cd "${stashdir}" &&
         exekutor git ${GITFLAGS} checkout ${options} "${tag}"  >&2
      ) || return 1

      if [ $? -ne 0 ]
      then
         log_error "Checkout failed, moving ${C_CYAN}${C_BOLD}${stashdir}${C_ERROR} to ${C_CYAN}${C_BOLD}${stashdir}.failed${C_ERROR}"
         log_error "You need to fix this manually and then move it back."

         rmdir_safer "${stashdir}.failed"
         exekutor mv "${stashdir}" "${stashdir}.failed"  >&2
         return 1
      fi
   else
      log_fluff "Already on proper branch \"${branch}\""
   fi
}

#  aka fetch
git_update_project()
{
   log_entry "git_update_project" "$@"

   [ $# -lt 8 ] && internal_fail "parameters missing"

   local reposdir="$1" ; shift
   local name="$1"; shift
   local url="$1"; shift
   local branch="$1"; shift
   local tag="$1"; shift
   local scm="$1"; shift
   local scmoptions="$1"; shift
   local stashdir="$1"; shift

   local options
   local remote

   options="`get_scmoption "${scmoptions}" "update"`"
   remote="`_get_fetch_remote "${url}"`" || internal_fail "can't figure out remote"

   log_info "Fetching ${C_MAGENTA}${C_BOLD}${stashdir}${C_INFO} ..."

   (
      exekutor cd "${stashdir}" &&
      exekutor git ${GITFLAGS} fetch "$@" ${options} ${GITOPTIONS} "${remote}" >&2
   ) || fail "git fetch of \"${stashdir}\" failed"
}


#  aka pull
git_upgrade_project()
{
   log_entry "git_upgrade_project" "$@"

   [ $# -lt 8 ] && internal_fail "parameters missing"

   local reposdir="$1" ; shift
   local name="$1"; shift
   local url="$1"; shift
   local branch="$1"; shift
   local tag="$1"; shift
   local scm="$1"; shift
   local scmoptions="$1"; shift
   local stashdir="$1"; shift

   local options
   local remote

   options="`get_scmoption "${scmoptions}" "upgrade"`"
   remote="`_get_fetch_remote "${url}"`" || internal_fail "can't figure out remote"

   log_info "Pulling ${C_MAGENTA}${C_BOLD}${stashdir}${C_INFO} ..."

   (
      exekutor cd "${stashdir}" &&
      exekutor git ${GITFLAGS} pull "$@" ${scmoptions} ${GITOPTIONS} "${remote}" >&2
   ) || fail "git pull of \"${stashdir}\" failed"

   if [ ! -z "${tag}" ]
   then
      git_checkout "$@"  >&2
   fi
}


git_status_project()
{
   log_entry "git_status_project" "$@"

   [ $# -lt 8 ] && internal_fail "parameters missing"

   local reposdir="$1" ; shift
   local name="$1"; shift
   local url="$1"; shift
   local branch="$1"; shift
   local tag="$1"; shift
   local scm="$1"; shift
   local scmoptions="$1"; shift
   local stashdir="$1"; shift

   log_info "Status ${C_MAGENTA}${C_BOLD}${stashdir}${C_INFO} ..."

   local options

   options="`get_scmoption "${scmoptions}" "status"`"

   (
      exekutor cd "${stashdir}" &&
      exekutor git ${GITFLAGS} status "$@" ${options} ${GITOPTIONS} >&2
   ) || fail "git status of \"${stashdir}\" failed"
}


git_set_url_project()
{
   log_entry "git_set_url_project" "$@"

   local stashdir="$1"
   local remote="$2"
   local url="$3"

   (
      cd "${stashdir}" &&
      git remote set-url "${remote}" "${url}"  >&2 &&
      git fetch "${remote}"  >&2  # prefetch to get new branches
   ) || exit 1
}


git_search_local_project()
{
   log_entry "git_search_local_project [${LOCAL_PATH}]" "$@"

   local url="$1"
   local name="$2"
   local branch="$3"

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

      found="`_git_search_local "${realdir}" "${name}" "${branch}"`" || exit 1
      if [ ! -z "${found}" ]
      then
         echo "${found}"
         return
      fi
   done

   IFS="${DEFAULT_IFS}"
   return 1
}


git_plugin_initialize()
{
   log_debug ":git_plugin_initialize:"

   [ -z "${MULLE_BOOTSTRAP_SCM_SH}" ] && . mulle-bootstrap-scm.sh
   [ -z "${MULLE_BOOTSTRAP_GIT_SH}" ] && . mulle-bootstrap-git.sh
}


git_plugin_initialize

:




