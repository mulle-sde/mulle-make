# shellcheck shell=bash
# shellcheck disable=SC2236
# shellcheck disable=SC2166
# shellcheck disable=SC2006
#
#   Copyright (c) 2022 Nat! - Mulle kybernetiK
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
MULLE_MAKE_LOG_SH="included"


make::log::usage()
{
   [ "$#" -ne 0 ] && log_error "$*"

    cat <<EOF >&2
Usage:
   ${MULLE_USAGE_NAME} log [options] [command] 

   List available build logs or run arbitrary commands on them like
   'cat' or 'grep', where 'cat' is the default.

   Grep for 'error:' through all project logs with:

      ${MULLE_USAGE_NAME} log grep 'error:'

Options:
   -t <tool>  : restrict to tool

Commands:
   list       : list available build logs
   clean      : remove all build logs
   <tool> ... : use cat, grep -E ack to execute on the logfiles

EOF
  exit 1
}


make::log::clean_usage()
{
   [ "$#" -ne 0 ] && log_error "$*"

    cat <<EOF >&2
Usage:
   ${MULLE_USAGE_NAME} log clean

   Clean all build logs.

EOF
  exit 1
}

make::log::list_usage()
{
   [ "$#" -ne 0 ] && log_error "$*"

    cat <<EOF >&2
Usage:
   ${MULLE_USAGE_NAME} log list

   List available build logs.

EOF
  exit 1
}


make::log::list()
{
   log_entry "make::log::list" "$@"

   local logsdir="$1"; shift

   [ $# -eq 0 ] || make::log::list_usage "Superflous arguments \"$*\""

   local i

   .foreachfile i in "${logsdir}"/*.*.log
   .do
      printf "%s\n" "${i#${logsdir}/}"
   .done
}


make::log::clean()
{
   log_entry "make::log::clean" "$@"

   local logsdir="$1"; shift

   [ $# -eq 0 ] || make::log::clean_usage "Superflous arguments \"$*\""

   local i

   .foreachfile i in "${logsdir}"/*.*.log
   .do
      _remove_file_if_present "$i"
   .done
   _remove_file_if_present "${logsdir}/.count"
}


make::log::cat()
{
   log_entry "make::log::cat" "$@"

   local logsdir="$1" 
   local tool="$2"

   shift 2 

   local found 

   if [ -z "${OPTION_TOOL}" ]
   then
      log_debug "Log pattern : ${logsdir}/*.*.log"
      .foreachfile i in "${logsdir}"/*.*.log
      .do
         log_info "${C_RESET_BOLD}${i}:"
         if [ $# -eq 0 ]
         then
            rexekutor cat "${i}"
         else
            exekutor "$@" "${i}"
         fi
         found='YES'
      .done
   else 
      log_debug "Log pattern : ${logsdir}/*.${OPTION_TOOL}.log"
      .foreachfile i in "${logsdir}"/*.${OPTION_TOOL}.log
      .do
         log_info "${C_RESET_BOLD}${i}:"
         if [ $# -eq 0 ]
         then
            rexekutor cat "${i}"
         else
            exekutor "$@" "${i}"
         fi
         found='YES'
      .done
   fi    

   if [ -z "${found}" ]
   then
      log_verbose "No logs match"
   fi
}



#
# We don't expect many parameters here, so we get them tradionally as arguments
#
make::log::main()
{
   log_entry "make::log::main" "$@"

   while [ $# -ne 0 ]
   do
      case "$1" in
         -h*|--help|help)
            make::log::usage
         ;;

         -t|--tool)
            [ $# -eq 1 ] && fail "Missing argument to \"$1\""
            shift

            OPTION_TOOL="$1"
         ;;

         -*)
            make::log::usage "Unknown option \"$1\""
         ;;

         *)
            break
         ;;
      esac

      shift
   done

   local name
   local srcdir 
   local logsdir 
   local kitchendir 

   include "mulle-make::build"

   srcdir="${PWD}"
   if ! make::build::__determine_directories "NO"
   then
      log_info "No log files found"
      return 0
   fi

   case "$1" in
      list)
         shift
         make::log::list "${logsdir}" "$@"
      ;;

      clean)
         shift
         make::log::clean "${logsdir}" "$@"
      ;;

      ""|*)
         make::log::cat "${logsdir}" "${OPTION_TOOL}" "$@" 
      ;;
   esac
}

