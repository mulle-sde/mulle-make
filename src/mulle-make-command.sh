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
MULLE_MAKE_COMMAND_SH="included"


suggest_binary_install()
{
   log_entry "suggest_binary_install" "$@"

   local toolname="$1"

   case "${toolname}" in
      mulle-cl*)
         case "${MULLE_UNAME}" in
            darwin)
               echo "brew install mulle-objc-developer"
            ;;

            *)
               echo "Visit https://mulle-objc.github.io/ for instructions how to install ${toolname}"
            ;;
         esac
      ;;

      *)
         case "${MULLE_UNAME}" in
            darwin)
               echo "brew install ${toolname}"
            ;;

            linux)
               if command -v "apt-get" > /dev/null 2>&1
               then
                  echo "apt-get install ${toolname}"
               else
                  if command -v "yum" > /dev/null 2>&1
                  then
                     echo "yum install ${toolname}"
                  else
                     echo "You need to install \"${toolname}\" manually"
                  fi
               fi
            ;;

            FreeBSD)
               if command -v "pkg" > /dev/null 2>&1
               then
                  echo "pkg install ${toolname}"
               else
                  if command -v "pkg_add" > /dev/null 2>&1
                  then
                     echo "pkg_add -r ${toolname}"
                  else
                     echo "You need to install \"${toolname}\" manually"
                  fi
               fi
            ;;

            *)
               echo "You need to install \"${toolname}\" manually"
            ;;
         esac
      ;;
   esac
}


which_binary()
{
   log_entry "which_binary" "$@"

   local toolname="$1"

   case "${MULLE_UNAME}" in
      mingw)
         case "${toolname}" in
            *.exe)
            ;;

            *)
               toolname="${toolname}.exe"
            ;;
         esac
      ;;
   esac

   command -v "${toolname}" 2> /dev/null
}


#
# used by test scripts outside of mulle-make
#
assert_binary()
{
   log_entry "assert_binary" "$@"

   local toolname="$1"
   local toolfamily="$2"

   [ -z "${toolname}" ] && internal_fail "toolname for \"${toolfamily}\" is empty"

   local path

   if ! which_binary "${toolname}"
   then
      fail "${toolname} is an unknown build tool (PATH=$PATH)"
   fi
   # echo "$path"
}


#
# toolname : ex. mulle-clang
# toolfamily: CC
# tooldefaultname: compiler
#
verify_binary()
{
   log_entry "verify_binary" "$@"

   local toolname="$1"
   local toolfamily="$2"
   local tooldefaultname="$3"

   [ -z "${toolname}" ] && internal_fail "toolname for \"${toolfamily}\" is empty"

   local path

   path="`which_binary "${toolname}" `"
   if [ ! -z "${path}" ]
   then
      log_fluff "${toolfamily:-${tooldefaultname}} is \"${path}\""
      echo "${path}"
      return 0
   fi

   #
   # If the user (via config) specified a certain tool, then it not being
   # there is bad.
   # Otherwise it's maybe OK (f.e. only using xcodebuild not cmake)
   #
   toolname="`extensionless_basename "${toolname}"`"
   tooldefaultname="`extensionless_basename "${tooldefaultname}"`"

   if [ "${toolname}" != "${tooldefaultname}" ]
   then
      fail "${toolfamily} named \"${toolname}\" not found in PATH.
Suggested fix:
${C_RESET}${C_BOLD}   `suggest_binary_install "${toolname}"`"
   else
      log_fluff "${toolfamily} named \"${toolname}\" not found in PATH"
   fi

   return 1
}


command_initialize()
{
   if [ -z "${MULLE_PATH_SH}" ]
   then
      # shellcheck source=../../mulle-bashfunctions/src/mulle-path.sh
      . "${MULLE_BASHFUNCTIONS_LIBEXEC_DIR}/mulle-path.sh" || exit 1
   fi
}

command_initialize

:


