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
  ${MULLE_EXECUTABLE} init [options]

Options
   -d : create default files
   -n : don't ask for editor

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


_print_repositories()
{
   cat <<EOF
#
# Add repository URLs to this file.
#
# mulle-bootstrap [fetch] will download these into ./stashes
# mulle-bootstrap [build] will build them into ./dependencies
#
# Each line consists of six fields, only the URL is necessary.
# Possible URL forms for repositories:
#
# https://www.mulle-kybernetik.com/repositories/MulleScion
# git@github.com:mulle-nat/MulleScion.git
# /Volumes/Source/srcM/MulleScion
#
# SUBDIR     : should be left empty
# BRANCH     : the specific branch to fetch.
# TAG        : can be a git branch or a tag to checkout.
# SCM        : defaults to git, can be tar, zip, svn
# SCMOPTIONS : usually left empty
#
# URL;SUBDIR;BRANCH;TAG;SCM;SCMOPTIONS
EOF
}


_print_embedded_repositories()
{
   cat <<EOF
#
# Add repository URLs to this file. Use SUBDIR to place the directory in
# your sourcetree
#
# mulle-bootstrap [fetch] will download the repostiory into a SUBDIR of your
# project root
# mulle-bootstrap [build] will NOT build it
#
# Each line consists of six fields, only the URL is necessary.
# Possible URL forms for repositories:
#
# https://www.mulle-kybernetik.com/repositories/MulleScion
# git@github.com:mulle-nat/MulleScion.git
# /Volumes/Source/srcM/MulleScion
#
# SUBDIR     : specfiy place to clone repository to
# BRANCH     : the specific branch to fetch.
# TAG        : can be a git branch or a tag to checkout.
# SCM        : defaults to git, can be tar, zip, svn
# SCMOPTIONS : usually left empty
#
# URL;SUBDIR;BRANCH;TAG;SCM;SCMOPTIONS
EOF
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

   OPTION_CREATE_DEFAULT_FILES="`read_config_setting "create_default_files" "NO"`"

   while [ $# -ne 0 ]
   do
      case "$1" in
         -h|-help|--help)
            init_usage
         ;;

         -n)
            MULLE_FLAG_ANSWER="NO"
         ;;

         -d)
            OPTION_CREATE_DEFAULT_FILES="YES"
         ;;

         -*)
            log_error "${MULLE_EXECUTABLE_FAIL_PREFIX}: Unknown init option $1"
            ${USAGE}

         ;;

         *)
            break
         ;;
      esac

      shift
   done

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

   if [ "${OPTION_CREATE_DEFAULT_FILES}" = "NO" ]
   then
      if [ "${MULLE_EXECUTABLE}" = "mulle-bootstrap" ]
      then
         log_info "${BOOTSTRAP_DIR} has been created. Use
   ${C_RESET}${C_BOLD}${MULLE_EXECUTABLE} repositories add <url>${C_INFO}
to specify dependencies and then install them with
   ${C_RESET}${C_BOLD}${MULLE_EXECUTABLE}${C_INFO}
E.g.:${C_RESET}${C_FAINT}
${MULLE_EXECUTABLE} repositories add 'https://github.com/madler/zlib.git'
${MULLE_EXECUTABLE}${C_INFO}
"
      else
         log_info "${BOOTSTRAP_DIR} has been created. Use
   ${C_RESET}${C_BOLD}${MULLE_EXECUTABLE} brews add <name>${C_INFO}
to specify brew formula to fetch and then install them with
   ${C_RESET}${C_BOLD}${MULLE_EXECUTABLE}${C_INFO}
E.g.:${C_RESET}${C_FAINT}
${MULLE_EXECUTABLE} brews add 'ack'
${MULLE_EXECUTABLE}${C_INFO}
"
      fi
      return
   fi

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

   log_verbose "\"${BOOTSTRAP_DIR}\" folder has been set up."

   local open

   open="`read_config_setting "open_${mainfile}_file" "ASK"`"
   if [ "${open}" = "ASK" ]
   then
      user_say_yes "Edit the ${C_MAGENTA}${C_BOLD}${mainfile}${C_WARNING} file now ?"
      if [ $? -eq 0 ]
      then
          open="YES"
      fi
   fi

   if [ "${open}" = "YES" ]
   then
      local editor

      editor="`read_config_setting "editor" "${EDITOR:-vi}"`"
      exekutor "${editor}" "${BOOTSTRAP_DIR}/${mainfile}"
   fi
}
