#! /bin/sh
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
#   POSSIBILITY OF SUCH DAMAGE.
MULLE_BOOTSTRAP_CLEAN_SH="included"


setup_clean_environment()
{
   [ -z "${DEPENDENCY_SUBDIR}"  ] && internal_fail "DEPENDENCY_SUBDIR is empty"
   [ -z "${CLONESBUILD_SUBDIR}" ] && internal_fail "CLONESBUILD_SUBDIR is empty"
   [ -z "${ADDICTION_SUBDIR}"   ] && internal_fail "ADDICTION_SUBDIR is empty"

   CLEAN_EMPTY_PARENTS="`read_config_setting "clean_empty_parent_folders" "YES"`"

   BUILD_CLEANABLE_FILES="${CLONESFETCH_SUBDIR}/.build_done"

   BUILD_CLEANABLE_SUBDIRS="`read_sane_config_path_setting "clean_folders" "${CLONESBUILD_SUBDIR}
${DEPENDENCY_SUBDIR}/tmp"`"
   OUTPUT_CLEANABLE_SUBDIRS="`read_sane_config_path_setting "output_clean_folders" "${DEPENDENCY_SUBDIR}"`"
   INSTALL_CLEANABLE_SUBDIRS="`read_sane_config_path_setting "install_clean_folders" "${CLONES_SUBDIR}
.bootstrap.auto"`"
   DIST_CLEANABLE_SUBDIRS="`read_sane_config_path_setting "dist_clean_folders" "${CLONES_SUBDIR}
${ADDICTION_SUBDIR}
.bootstrap.auto"`"
   EMBEDDED="`embedded_repository_directories_from_repos`"

   if [ ! -z "$EMBEDDED" ]
   then
      DIST_CLEANABLE_SUBDIRS="${DIST_CLEANABLE_SUBDIRS}
${EMBEDDED}"
   fi
}


_clean_usage()
{
   setup_clean_environment

   cat <<EOF >&2
   build   : useful to remove intermediate build files. it cleans
---
${BUILD_CLEANABLE_SUBDIRS}
${BUILD_CLEANABLE_FILES}
---

   output  : useful to rebuild. It cleans
---
${BUILD_CLEANABLE_SUBDIRS}
${BUILD_CLEANABLE_FILES}
${OUTPUT_CLEANABLE_SUBDIRS}
---

   dist    : remove all clones, dependencies, addictions. It cleans
---
${BUILD_CLEANABLE_SUBDIRS}
${OUTPUT_CLEANABLE_SUBDIRS}
${DIST_CLEANABLE_SUBDIRS}
---

   install  : useful if you know, you don't want to rebuild ever. It cleans
---
${BUILD_CLEANABLE_SUBDIRS}
${INSTALL_CLEANABLE_SUBDIRS}
---
EOF
}


clean_usage()
{
   cat <<EOF >&2
usage:
   mulle-bootstrap clean [build|dist|install|output]

EOF
   _clean_usage
   exit 1
}


clean_asserted_folder()
{
   if [ -d "$1" ]
   then
      log_info "Deleting \"$1\""

      rmdir_safer "$1"
   else
      log_fluff "\"$1\" doesn't exist"
   fi
}


clean_asserted_file()
{
   if [ -f "$1" ]
   then
      log_info "Deleting \"$1\""

      remove_file_if_present "$1"
   else
      log_fluff "\"$1\" doesn't exist"
   fi
}



clean_parent_folders_if_empty()
{
   local dir
   local stop

   if [ "${CLEAN_EMPTY_PARENTS}" = "YES" ]
   then
      dir="$1"
      stop="$2"

      local parent

      parent="${dir}"
      while :
      do
         parent="`dirname -- "${parent}"`"
         if [ "${parent}" = "." -o "${parent}" = "${stop}" ]
         then
             break
         fi

         if dir_is_empty "${parent}"
         then
            assert_sane_subdir_path "${parent}"
            log_info "Deleting \"${parent}\" because it was empty. "
            log_fluff "Set \"${BOOTSTRAP_SUBDIR}/config/clean_empty_parent_folders\" to NO if you don't like it."
            exekutor rmdir "${parent}"
         fi
      done
   fi
}


clean_files()
{
   local files

   files="$1"

   local file
   local old

   old="${IFS:-" "}"

   IFS="
"
   for file in ${files}
   do
      IFS="${old}"

      clean_asserted_file "${file}"
   done

   IFS="${old}"
}


clean_directories()
{
   local directories
   local flag

   directories="$1"
   flag="$2"

   local directory
   local old

   old="${IFS:-" "}"
   IFS="
"
   for directory in ${directories}
   do
      IFS="${old}"
      clean_asserted_folder "${directory}"
      clean_parent_folders_if_empty "${directory}" "${PWD}"
      flag="YES"
   done

   echo "$flag"

   IFS="${old}"
}


#
# for mingw its faster, if we have separate clean functions
#
# cleanability is checked, because in some cases its convenient
# to have other tools provide stuff besides /include and /lib
# and sometimes  projects install other stuff into /share
#
_clean_execute()
{
   local flag

   [ -z "${DEPENDENCY_SUBDIR}"  ] && internal_fail "DEPENDENCY_SUBDIR is empty"
   [ -z "${CLONESBUILD_SUBDIR}" ] && internal_fail "CLONESBUILD_SUBDIR is empty"
   [ -z "${ADDICTION_SUBDIR}"   ] && internal_fail "ADDICTION_SUBDIR is empty"

   flag="NO"
   CLEAN_EMPTY_PARENTS="`read_config_setting "clean_empty_parent_folders" "YES"`"


   case "${COMMAND}" in
      build)
         BUILD_CLEANABLE_SUBDIRS="`read_sane_config_path_setting "clean_folders" "${CLONESBUILD_SUBDIR}
${DEPENDENCY_SUBDIR}/tmp"`"
         BUILD_CLEANABLE_FILES="${CLONESFETCH_SUBDIR}/.build_done"
         clean_directories "${BUILD_CLEANABLE_SUBDIRS}" "${flag}"
         clean_files "${BUILD_CLEANABLE_FILES}"
         return
      ;;

      dist|output|install)
         BUILD_CLEANABLE_SUBDIRS="`read_sane_config_path_setting "clean_folders" "${CLONESBUILD_SUBDIR}
${DEPENDENCY_SUBDIR}/tmp"`"
         BUILD_CLEANABLE_FILES="${CLONESFETCH_SUBDIR}/.build_done"
         flag="`clean_directories "${BUILD_CLEANABLE_SUBDIRS}" "${flag}"`"
         clean_files "${BUILD_CLEANABLE_FILES}"
      ;;
   esac

   case "${COMMAND}" in
      output)
         OUTPUT_CLEANABLE_SUBDIRS="`read_sane_config_path_setting "output_clean_folders" "${DEPENDENCY_SUBDIR}"`"
         clean_directories "${OUTPUT_CLEANABLE_SUBDIRS}" "${flag}"
         clean_files "${OUTPUT_CLEANABLE_FILES}"
         return
      ;;

      dist)
         OUTPUT_CLEANABLE_SUBDIRS="`read_sane_config_path_setting "output_clean_folders" "${DEPENDENCY_SUBDIR}"`"
         flag="`clean_directories "${OUTPUT_CLEANABLE_SUBDIRS}" "${flag}"`"
         clean_files "${OUTPUT_CLEANABLE_FILES}"
      ;;
   esac

   case "${COMMAND}" in
      install)
         INSTALL_CLEANABLE_SUBDIRS="`read_sane_config_path_setting "install_clean_folders" "${CLONES_SUBDIR}
.bootstrap.auto"`"
         clean_directories "${INSTALL_CLEANABLE_SUBDIRS}" "${flag}"
         clean_files "${INSTALL_CLEANABLE_FILES}"
         return
      ;;
   esac

   case "${COMMAND}" in
      dist)
         DIST_CLEANABLE_SUBDIRS="`read_sane_config_path_setting "dist_clean_folders" "${CLONES_SUBDIR}
${ADDICTION_SUBDIR}
.bootstrap.auto"`"
         EMBEDDED="`embedded_repository_directories_from_repos`"

         if [ ! -z "$EMBEDDED" ]
         then
            DIST_CLEANABLE_SUBDIRS="${DIST_CLEANABLE_SUBDIRS}
${EMBEDDED}"
         fi
         clean_directories "${DIST_CLEANABLE_SUBDIRS}" "${flag}"
         clean_files "${DIST_CLEANABLE_FILES}"
      ;;
   esac
}


clean_execute()
{
   local flag

   flag="`_clean_execute "$@"`"
   if [ "$flag" = "NO" ]
   then
      log_info "Nothing configured to clean"
   fi
}


#
# don't rename these settings anymore, the consequences can be catastrophic
# for users of previous versions.
# Also don't change the search paths for read_sane_config_path_setting
#
clean_main()
{
   log_fluff "::: clean :::"

   [ -z "${MULLE_BOOTSTRAP_BUILD_ENVIRONMENT_SH}" ] && . mulle-bootstrap-build-environment.sh
   [ -z "${MULLE_BOOTSTRAP_SETTINGS_SH}" ] && . mulle-bootstrap-settings.sh
   [ -z "${MULLE_BOOTSTRAP_REPOSITORIES_SH}" ] && . mulle-bootstrap-repositories.sh

   COMMAND=

   while [ $# -ne 0 ]
   do
      case "$1" in
         -h|-help|--help)
            COMMAND=help
         ;;

         -*)
            log_error "unknown option $1"
            COMMAND=help
         ;;

         *)
            break
         ;;
      esac

      shift
   done

   if [ -z "${COMMAND}" ]
   then
      COMMAND=${1:-"output"}
      [ $# -eq 0 ] || shift
   fi


   case "$COMMAND" in
      output|dist|build|install)
         clean_execute "$@"
      ;;

      help)
         clean_usage
      ;;

      _help)
         _clean_usage
      ;;

      *)
         log_error "Unknown command \"${COMMAND}\""
         clean_usage
      ;;
   esac
}
