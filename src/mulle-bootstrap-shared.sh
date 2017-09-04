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
#   POSSIBILITY OF SUCH DAMAGE.
#
MULLE_BOOTSTRAP_SHARED_SH="included"


shared_usage()
{
   cat <<EOF >&2
Usage:
   ${MULLE_EXECUTABLE_NAME} shared init [options]
   ${MULLE_EXECUTABLE_NAME} shared add [options] <url>
   ${MULLE_EXECUTABLE_NAME} shared remove [options] <name>
   ${MULLE_EXECUTABLE_NAME} shared uninit [options]
   ${MULLE_EXECUTABLE_NAME} shared list [options]

Commands:
   init           : Initialize a shared build info repository ($OPTION_DIRECTORY)
   add <url>      : Add another build info repository (git) at URL
   remove <name>  : Remove build info repository (git) from URL
   uninit         : Completely remove shared build info repositories
   list           : List current build info repositories available. Use
                    \'${MULLE_EXECUTABLE_NAME} -v shared list\' to see contents.

Options:
   -d <dir>       : specify build info directory to use

EOF

   exit 1
}


shared_init()
{
   log_entry "shared_init" "$@"

   local repodir="$1"
   local do_add="NO"

   mkdir_if_missing "${repodir}" || exit 1
   if ! git_is_repository "${repodir}"
   then
      (
         exekutor cd "${repodir}" || exit 1
         exekutor git init &&
         exekutor git submodule init
      ) || return 1
      do_add="${OPTION_ADD}"
   fi

   (
      OPTION_USER="YES"
      if [ -d "${BOOTSTRAP_DIR}" -o -d "${BOOTSTRAP_DIR}.local" ]
      then
         OPTION_USER="NO"
      fi
      _config_write "shared_buildinfo_path" "${repodir}"
   ) || return 1

   # now add repos
   if [ "${do_add}" = "YES" ]
   then
      shared_add "$@"
   fi
}


shared_uninit()
{
   log_entry "shared_uninit" "$@"

   local repodir="$1"

   [ -d "${repodir}" ] || fail "The shared build info repository ${C_RESET_BOLD}${repodir}${C_ERROR} does not exist."

   rmdir_safer "${repodir}"
   (
      OPTION_USER="YES"
      if [ -d "${BOOTSTRAP_DIR}" -o -d "${BOOTSTRAP_DIR}.local" ]
      then
         OPTION_USER="NO"
      fi
      _config_delete "shared_buildinfo_path"
   )
}


shared_upgrade()
{
   log_entry "shared_upgrade" "$@"

   local repodir="$1"

   git_is_repository "${repodir}" || fail "The shared build info repository
${C_RESET_BOLD}${repodir}${C_ERROR} does not exist (or is no git repo)."

   (
      exekutor cd "${repodir}" &&
      exekutor git submodule update --recursive --remote
   ) || exit 1

}


shared_add()
{
   log_entry "shared_add" "$@"

   local repodir="$1"
   local urls="$2"

   git_is_repository "${repodir}" || fail "The shared build info repository
${C_RESET_BOLD}${repodir}${C_ERROR} does not exist (or is no git repo)."

   local url
   IFS="
"
   for url in ${urls}
   do
      IFS="${DEFAULT_IFS}"
      (
         exekutor cd "${repodir}" &&
         exekutor git submodule add "${url}"
      ) || exit 1
   done

   IFS="${DEFAULT_IFS}"
}


shared_remove()
{
   log_entry "shared_remove" "$@"

   local repodir="$1"
   local names="$2"

   git_is_repository "${repodir}" || fail "The shared build info repository
${C_RESET_BOLD}${repodir}${C_ERROR} does not exist (or is no git repo)."

   local name
   IFS="
"
   for name in ${names}
   do
      IFS="${DEFAULT_IFS}"
      (
         exekutor cd "${repodir}"
         if [ ! -e ".git/modules/${name}" ]
         then
            fail "${name} is unknown"
         fi

         exekutor git submodule deinit -f -- "${name}" &&
         exekutor rm -rf ".git/modules/${name}" &&
         exekutor git rm -f "${name}"

      ) || exit 1
   done

   IFS="${DEFAULT_IFS}"
}


shared_list()
{
   log_entry "shared_list" "$@"

   local repodir="$1"

   git_is_repository "${repodir}" || fail "The shared build info repository
${C_RESET_BOLD}${repodir}${C_ERROR} does not exist (or is no git repo).
Create one with: ${C_RESET_BOLD}${MULLE_EXECUTABLE_NAME} shared init${C_ERROR}"

   (
      exekutor cd "${repodir}" &&
      IFS="
"
      for name in `exekutor git submodule--helper list | exekutor cut -f 2`
      do
         log_info "${name}"
         [ -d "${name}" ] || internal_fail "${repodir}/${name} is missing"
         (
            cd "${name}" ;
            for i in `exekutor ls -1d *.build 2> /dev/null`
            do
               line="`echo "${i}" | sed 's/^/   /'`"
               log_verbose "${line}"
            done
         )
         log_verbose
      done
   ) || exit 1
}


#
# this script creates a .bootstrap folder with some
# demo files.
#
shared_main()
{
   local mainfile

   [ -z "${MULLE_BOOTSTRAP_LOCAL_ENVIRONMENT_SH}" ] && . mulle-bootstrap-local-environment.sh
   [ -z "${MULLE_BOOTSTRAP_SETTINGS_SH}" ]          && . mulle-bootstrap-settings.sh
   [ -z "${MULLE_BOOTSTRAP_FUNCTIONS_SH}" ]         && . mulle-bootstrap-functions.sh
   [ -z "${MULLE_BOOTSTRAP_GIT_SH}" ]               && . mulle-bootstrap-git.sh

   [ -z "${DEFAULT_SHARED_BUILDINFO_PATH}" ] && internal_fail "DEFAULT_SHARED_BUILDINFO_PATH" not read_config_setting

   local OPTION_DIRECTORY
   local OPTION_URLS
   local DEFAULT_SHARED_BUILDINFO_URL="https://github.com/mulle-nat/mulle-shared-buildinfo"
   local OPTION_ADD="YES"

   OPTION_URLS="${DEFAULT_SHARED_BUILDINFO_URL}"
   OPTION_DIRECTORY="`read_config_setting "shared_buildinfo_path" "${DEFAULT_SHARED_BUILDINFO_PATH}"`"

   while [ $# -ne 0 ]
   do
      case "$1" in
         -h|-help|--help)
            shared_usage
         ;;

         *)
            break
         ;;
      esac
   done

   local cmd

   [ $# -eq 0 ] && shared_usage
   cmd="$1"
   shift

   while [ $# -ne 0 ]
   do
      case "${cmd}" in
         init)
            case "$1" in
               -u|--url)
                  [ $# -eq 1 ] && fail "Missing argument to $1"
                  shift

                  OPTION_URLS="`add_line "${OPTION_URLS}" "$1"`"
                  shift
                  continue
               ;;
            esac
            case "$1" in
               -n|--no-add)
                  OPTION_ADD="NO"
                  shift
                  continue
               ;;
            esac
         ;;
      esac

      case "$1" in
         -h|-help|--help)
            shared_usage
         ;;

         -d|--directory)
            [ $# -eq 1 ] && fail "Missing argument to $1"
            shift

            OPTION_DIRECTORY="$1"
         ;;

         -*)
            log_error "${MULLE_EXECUTABLE_FAIL_PREFIX}: Unknown init option $1"
            shared_usage
         ;;

         *)
            break
         ;;
      esac

      shift
   done

   case "${cmd}" in
      add|remove)
         [ $# -eq 1 ] || fail "Missing argument to $1"
         OPTION_URLS="$1"
         shift
      ;;

      init|show|list|uninit|upgrade)
      ;;

      *)
         log_error "${MULLE_EXECUTABLE_FAIL_PREFIX}: Unknown shared command \"${cmd}\""
         shared_usage
      ;;
   esac

   [ $# -ne 0 ] && shared_usage

   [ -z "${OPTION_DIRECTORY}" ] && fail "Directory is empty, can't proceed"

   "shared_${cmd}" "${OPTION_DIRECTORY}" "${OPTION_URLS}"
}

