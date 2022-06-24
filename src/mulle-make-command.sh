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


make::command::suggest_binary_install()
{
   log_entry "make::command::suggest_binary_install" "$@"

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


make::command::r_binary_name()
{
   log_entry "make::command::r_binary_name" "$@"

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

      windows)
         case "${toolname}" in
            *.exe)
            ;;

            *)
               toolname="${toolname}.exe"
            ;;
         esac
      ;;
   esac
   RVAL="${toolname}"
}


make::command::which_binary()
{
   log_entry "make::command::which_binary" "$@"

   local binary="$1"

   command -v "${binary}" 2> /dev/null
}


#
# toolname : ex. mulle-clang
# toolfamily: CC
# tooldefaultname: compiler
#
make::command::r_verify_binary()
{
   log_entry "make::command::r_verify_binary" "$@"

   local toolname="$1"
   local toolfamily="$2"
   local tooldefaultname="$3"

   [ -z "${toolname}" ] && _internal_fail "toolname for \"${toolfamily}\" is empty"

   # on wsl, binaries can be like "cmake"´or "cmake.exe" ?
   local filepath
   local binary

   # make::command::r_binary_name "${toolname}"
   binary="${toolname}"

   case "${binary}" in
      /*)
         if [ ! -x "${binary}" ]
         then
            fail "\"${toolname}\" is not present as an executable"
         fi
         filepath="${binary}"

         r_basename="${binary}"
         binary="${RVAL}"
      ;;

      *)
         filepath="`make::command::which_binary "${binary}"`"
      ;;
   esac

   if [ ! -z "${filepath}" ]
   then
      log_debug "${toolfamily:-${tooldefaultname}} is \"${filepath}\""
      RVAL="${filepath}"
      return 0
   fi

   #
   # If the user (via config) specified a certain tool, then it not being
   # there is bad.
   # Otherwise it's maybe OK (f.e. only using xcodebuild not cmake)
   #
   r_extensionless_basename "${binary}"
   toolname="${RVAL}"
   r_extensionless_basename "${tooldefaultname}"
   tooldefaultname="${RVAL}"

   if [ "${toolname}" != "${tooldefaultname}" ]
   then
      fail "${toolfamily} named \"${binary}\" not found in PATH.
Suggested fix:
${C_RESET}${C_BOLD}   `make::command::suggest_binary_install "${binary}"`"
   else
      log_fluff "${toolfamily} named \"${binary}\" not found in PATH"
   fi

   return 1
}


make::command::initialize()
{
   if [ -z "${MULLE_PATH_SH}" ]
   then
      # shellcheck source=../../mulle-bashfunctions/src/mulle-path.sh
      . "${MULLE_BASHFUNCTIONS_LIBEXEC_DIR}/mulle-path.sh" || exit 1
   fi
}

make::command::initialize

:


