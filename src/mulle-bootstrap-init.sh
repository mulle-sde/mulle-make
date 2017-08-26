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
#   POSSIBILITY OF SUCH DAMAGE.
#
MULLE_BOOTSTRAP_INIT_SH="included"


init_usage()
{
    cat <<EOF >&2
Usage:
  ${MULLE_EXECUTABLE} init [options] [directory]

  Make a project work with mulle-bootstrap. By default the current directory
  is assumed. You can also specify a different one. It will be created, if
  it doesn't exist yet.

Options
   -c       : create default files
   -n       : do not setup a shared buildinfo repository (if none present)

EOF
  exit 1
}


init_add_brews()
{
   redirect_exekutor "${BOOTSTRAP_DIR}/brews" cat <<EOF
#
# Add homebrew packages to this file (https://brew.sh/)
#
# mulle-bootstrap [fetch] will install those into "${ADDICTIONS_DIR}"
#
# e.g.
# byacc
#
EOF
}


# no more large blurbs, since we have `mulle-bootstrap repository` now

_print_repositories()
{
   cat <<EOF
# URL;UNUSED;BRANCH;TAG;SOURCE;OPTIONS
EOF
}


_print_embedded_repositories()
{
   cat <<EOF
# URL;SUBDIR;BRANCH;TAG;SOURCE;OPTIONS
EOF
}


create_default_files()
{

   log_fluff "Create default files"

#cat <<EOF > "${BOOTSTRAP_DIR}/pips"
# add projects that should be installed by pip
# try to avoid it, since it needs sudo (uncool)
# mod-pbxproj
#EOF

   init_add_brews

   if [ "${MULLE_EXECUTABLE}" = "mulle-bootstrap" ]
   then
      mainfile="repositories"

      _print_repositories > "${BOOTSTRAP_DIR}/repositories"
      _print_embedded_repositories > "${BOOTSTRAP_DIR}/embedded_repositories"
   else
      mainfile="brews"
   fi
}


blurb_after_init()
{
   local dir="$1"

   log_verbose "\"${BOOTSTRAP_DIR}\" folder has been set up."

   local extraline

   if [ ! -z "${dir}" ]
   then
      extraline="
cd \"${OPTION_DIRECTORY}\""
   fi

   if [ "${MULLE_EXECUTABLE}" = "mulle-bootstrap" ]
   then
         log_info "Done! Use ${C_RESET}${C_BOLD}${MULLE_EXECUTABLE} repositories add <url>${C_INFO}
to specify dependencies and then install them with
   ${C_RESET}${C_BOLD}${MULLE_EXECUTABLE}${C_INFO}
E.g.:${C_RESET}${C_FAINT}${extraline}
${MULLE_EXECUTABLE} repositories add 'https://github.com/madler/zlib.git'
${MULLE_EXECUTABLE}${C_INFO}
"
   else
      log_info "Done!  Use ${C_RESET}${C_BOLD}${MULLE_EXECUTABLE} brews add <name>${C_INFO}
to specify brew formula to fetch and then install them with
   ${C_RESET}${C_BOLD}${MULLE_EXECUTABLE}${C_INFO}
E.g.:${C_RESET}${C_FAINT}${extraline}
${MULLE_EXECUTABLE} brews add 'ack'
${MULLE_EXECUTABLE}${C_INFO}
"
   fi
}


do_init()
{
   if [ -d "${BOOTSTRAP_DIR}" ]
   then
      fail "\"${BOOTSTRAP_DIR}\" already exists"
   fi

   log_fluff "Create \"${BOOTSTRAP_DIR}\""
   mkdir_if_missing "${BOOTSTRAP_DIR}"

   redirect_exekutor "${BOOTSTRAP_DIR}/version" cat <<EOF
# required mulle-bootstrap version
${MULLE_EXECUTABLE_VERSION_MAJOR}.0.0
EOF
}


do_default_config()
{
   if [ -z "`_config_read "git_mirror"`" ]
   then
      (
         _config_write "git_mirror" "${DEFAULT_GIT_MIRROR}"
      ) || return 1
   fi

   if [ -z "`_config_read "archive_cache"`" ]
   then
      (
         _config_write "archive_cache" "${DEFAULT_ARCHIVE_CACHE}"
      ) || return 1
   fi
}


#
# this script creates a .bootstrap folder with some
# demo files.
#
init_main()
{
   local mainfile

   [ -z "${MULLE_BOOTSTRAP_LOCAL_ENVIRONMENT_SH}" ] && . mulle-bootstrap-local-environment.sh
   [ -z "${MULLE_BOOTSTRAP_SETTINGS_SH}" ]          && . mulle-bootstrap-settings.sh
   [ -z "${MULLE_BOOTSTRAP_FUNCTIONS_SH}" ]         && . mulle-bootstrap-functions.sh

   local OPTION_CREATE_DEFAULT_FILES
   local OPTION_DIRECTORY
   local OPTION_INIT_SHARED="YES"
   local OPTION_DO_DEFAULT_CONFIG="YES"

   OPTION_DIRECTORY=
   OPTION_CREATE_DEFAULT_FILES="`read_config_setting "create_default_files" "NO"`"

   while [ $# -ne 0 ]
   do
      case "$1" in
         -h|-help|--help)
            init_usage
         ;;

         -n)
            OPTION_INIT_SHARED="NO"
         ;;

         -c|--create-default-files)
            OPTION_CREATE_DEFAULT_FILES="YES"
         ;;

         --no-default-config)
            OPTION_DO_DEFAULT_CONFIG="YES"
         ;;

         -*)
            log_error "${MULLE_EXECUTABLE_FAIL_PREFIX}: Unknown init option $1"
            init_usage
         ;;

         *)
            break
         ;;
      esac

      shift
   done

   if [ $# -eq 1 ]
   then
      OPTION_DIRECTORY="$1"
      shift
   fi

   [ $# -eq 0 ] || init_usage

   if [ ! -z "${OPTION_DIRECTORY}" ]
   then
      mkdir_if_missing "${OPTION_DIRECTORY}" || exit 1
   fi
   (
      if [ ! -z "${OPTION_DIRECTORY}" ]
      then
         cd "${OPTION_DIRECTORY}" || exit 1
      fi

      do_init

      if [ "${OPTION_DO_DEFAULT_CONFIG}" = "YES" ]
      then
         do_default_config
      fi

      if [ "${OPTION_CREATE_DEFAULT_FILES}" = "YES" ]
      then
         create_default_files
      fi

      if [ "${OPTION_INIT_SHARED}" = "YES" ]
      then
         [ -z "${MULLE_BOOTSTRAP_SHARED_SH}" ] && . mulle-bootstrap-shared.sh

         shared_main "init"
      fi

      blurb_after_init "${OPTION_DIRECTORY}"
   ) || exit 1
}
