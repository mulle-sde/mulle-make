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
MULLE_BOOTSTRAP_SCM_PLUGIN_TAR_SH="included"

_archive_test()
{
   local archive="$1"

   log_fluff "Testing ${C_MAGENTA}${C_BOLD}${archive}${C_INFO} ..."

   case "${archive}" in
      *.zip)
         redirect_exekutor /dev/null unzip -t "${archive}" || return 1
      ;;
   esac

   local tarcommand

   tarcommand="tf"

   case "${UNAME}" in
      darwin)
         # don't need it
      ;;

      *)
         case "${url}" in
            *.gz)
               tarcommand="tfz"
            ;;

            *.bz2)
               tarcommand="tfj"
            ;;

            *.x)
               tarcommand="tfJ"
            ;;
         esac
      ;;
   esac


   redirect_exekutor /dev/null tar ${tarcommand} ${TAROPTIONS} ${options} "${archive}" || return 1
}


_archive_unpack()
{
   local archive="$1"
   local scmoptions="$2"

   log_verbose "Extracting ${C_MAGENTA}${C_BOLD}${archive}${C_INFO} ..."

   case "${archive}" in
      *.zip)
         exekutor unzip "${archive}" || return 1
      ;;
   esac

   local tarcommand

   tarcommand="xf"

   case "${UNAME}" in
      darwin)
         # don't need it
      ;;

      *)
         case "${url}" in
            *.gz)
               tarcommand="xfz"
            ;;

            *.bz2)
               tarcommand="xfj"
            ;;

            *.x)
               tarcommand="xfJ"
            ;;
         esac
      ;;
   esac

   local options

   options="`get_scmoption "${scmoptions}" "tar"`"

   exekutor tar ${tarcommand} ${TAROPTIONS} ${options} "${archive}" || return 1
}


#
# What we do is
# a) download the package using curl
# b) optionally copy it into a cache for next time
# c) create a temporary directory, extract into it
# d) move it into place
#
_tar_download()
{
   local download="$1"
   local url="$2"
   local scmoptions="$3"

   local archive_cache
   local cachable_path
   local cached_archive
   local filename
   local directory

   archive_cache="`read_config_setting "archive_cache" "${DEFAULT_ARCHIVE_CACHE}"`"

   if [ ! -z "${archive_cache}" -a "${archive_cache}" != "NO" ]
   then
      # fix for github
      case "${url}" in
         *github.com*/archive/*)
            directory="`dirname -- "${url}"`" # remove 3.9.2
            directory="`dirname -- "${directory}"`" # remove archives
            filename="`basename -- "${directory}"`-${download}"
         ;;

         *)
            filename="${download}"
         ;;
      esac

      cachable_path="${archive_cache}/${filename}"

      if [ -f "${cachable_path}" ]
      then
         cached_archive="${cachable_path}"
      fi
   fi

   if [ ! -z "${cached_archive}" ]
   then
      log_info "Using cached \"${cached_archive}\" for ${C_MAGENTA}${C_BOLD}${url}${C_INFO} ..."
      # we are in a tmp dir
      cachable_path=""

      if ! _archive_test "${filename}" || \
         ! validate_download "${cached_archive}" "${scmoptions}"
      then
         remove_file_if_present "${cached_archive}"
         cached_archive=""
      fi
      exekutor ln -s "${cached_archive}" "${download}" || fail "failed to symlink \"${cached_archive}\""
   fi

   local options

   options="`get_scmoption "${scmoptions}" "curl"`"

   if [ -z "${cached_archive}" ]
   then
      exekutor curl -O -L ${options} ${CURLOPTIONS} "${url}" || fail "failed to download \"${url}\""
      if ! validate_download "${download}" "${scmoptions}"
      then
         remove_file_if_present "${download}"
         fail "Can't download archive from \"${url}\""
      fi
   fi

   [ -f "${download}" ] || internal_fail "expected file \"${download}\" is mising"

   if [ -z "${cached_archive}" -a ! -z "${cachable_path}" ]
   then
      log_verbose "Caching \"${url}\" as \"${cachable_path}\" ..."
      mkdir_if_missing "${archive_cache}" || fail "failed to create archive cache \"${archive_cache}\""
      exekutor cp "${download}" "${cachable_path}" || fail "failed to copy \"${download}\" to \"${cachable_path}\""
   fi
}

###
### PLUGIN API
###

tar_clone_project()
{
   [ $# -lt 8 ] && internal_fail "parameters missing"

   local reposdir="$1"     # ususally .bootstrap.repos
   local name="$2"         # name of the clone
   local url="$3"          # URL of the clone
   local branch="$4"       # branch of the clone
   local tag="$5"          # tag to checkout of the clone
   local scm="$6"          # scm to use for this clone
   local scmoptions="$7"   # options to use on scm
   local stashdir="$8"     # stashdir of this clone (absolute or relative to $PWD)

   local tmpdir
   local archive
   local download
   local options
   local archivename
   local directory

   # fixup github
   download="`basename -- "${url}"`"
   archive="${download}"

   # remove .tar (or .zip et friends)
   archivename="`extension_less_basename "${download}"`"
   case "${archivename}" in
      *.tar)
         archivename="`extension_less_basename "${archivename}"`"
      ;;
   esac

   rmdir_safer "${name}.tmp"
   tmpdir="`exekutor mktemp -d "${name}.XXXXXXXX"`" || return 1
   (
      exekutor cd "${tmpdir}" || return 1

      _tar_download "${download}" "${url}" "${scmoptions}" || return 1

      _archive_unpack "${download}" "${scmoptions}" || return 1
      exekutor rm "${download}" || return 1
   ) || return 1

   archive_move_stuff "${tmpdir}" "${stashdir}" "${archivename}" "${name}"
}


tar_search_local_project()
{
   archive_search_local "$@"
}
