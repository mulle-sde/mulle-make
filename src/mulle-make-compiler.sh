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
MULLE_MAKE_COMPILER_SH="included"


platform_c_compiler()
{
   local name

   name="${OPTION_CC}"

   case "${UNAME}" in
      mingw)
         echo "${name:-cl}"
      ;;

      *)
         echo "${name:-cc}"
      ;;
   esac
}


platform_cxx_compiler()
{
   local name

   name="${OPTION_CXX}"

   case "${UNAME}" in
      mingw)
         echo "${name:-cl}"
      ;;

      *)
         echo "${name:-c++}"
      ;;
   esac
}


#
# assume default is release and the flags
# are set for that
#
_compiler_debug_options()
{
   local name="$1"

   case "${name%.*}" in
      cl|*-cl)
         echo "/Od /Zi"
      ;;

      *)
         echo "-g -O0"
      ;;
   esac
}


# compiler is re
compiler_sdk_parameter()
{
   local sdk="$1"

   if [ "${UNAME}" = "darwin" -a "${OPTION_DETERMINE_XCODE_SDK}" != "NO" ]
   then
      local sdkpath

      if [ "${sdk}" = "Default" ]
      then
         sdkpath="`xcrun --show-sdk-path`"
      else
         sdkpath="`xcrun --sdk "${sdk}" --show-sdk-path`"
      fi
      if [ "${sdkpath}" = "" ]
      then
         fail "SDK \"${sdk}\" is not installed"
      fi
      echo "${sdkpath}"
   fi
}


#
# Mash some known settings from xcodebuild together for regular
# OTHER_CFLAGS
# WARNING_CFLAGS
# COMPILER_PREPROCESSOR_DEFINITIONS
#
# In general it would be nice when using cmake, that the -I detection would
# be just done by find_library. Unfortunately, this doesn't work when you
# have header only libraries with no .a file.
# Therefore we need to add -Isystem here if passes
#
compiler_cppflags_value()
{
   log_entry "compiler_cppflags_value" "$@"

   local result

   result="`concat "${OPTION_CPPFLAGS}" "${OPTION_OTHER_CPPFLAGS}" `"

   if [ ! -z "$1" ]
   then
      local tmp

      # space bug ?
      #
      # the flags get passed in as quoted, if the path itself has spaces
      # this will not work I suspect. But let's try anyway
      #
      tmp="$(sed -e 's/ /\\ /g' <<< "$1")"
      tmp="`convert_path_to_flag "$1" "-isystem " "" `"

      result="`concat "${result}" "${tmp}" `"
   fi

   if [ ! -z "${result}" ]
   then
      echo "${result}"
   fi
}


_compiler_cflags_value()
{
   local compiler="$1"
   local configuration="$2"
   local addoptflags="${3:-YES}"

   local value
   local result
   local i

   value="${OPTION_WARNING_CFLAGS}"
   result="`concat "$result" "$value"`"

   if [ "${addoptflags}" = "YES" ]
   then
      case "${configuration}" in
         Debug)
            value="`_compiler_debug_options "${compiler}"`"
            result="`concat "$result" "$value"`"
         ;;
      esac
   fi

   case "${compiler%.*}" in
      c++|cc|gcc*|*clang*|"")
         IFS=","
         set -o noglob
         for i in ${OPTION_GCC_PREPROCESSOR_DEFINITIONS}
         do
            result="`concat "$result" "-D${i}"`"
         done
         IFS="${DEFAULT_IFS}"
         set +o noglob
      ;;
   esac

   echo "${result}"
}


compiler_cflags_value()
{
   log_entry "compiler_cflags_value" "$@"

   local compiler="$1"
   local configuration="$2"
   local addoptflags="$3"

   result="${OPTION_CFLAGS}"
   value="${OPTION_OTHER_CFLAGS}"
   result="`concat "$result" "$value"`"

   value="`_compiler_cflags_value "${compiler}" "${configuration}" "${addoptflags}"`"
   result="`concat "$result" "$value"`"

   echo "${result}"
}


compiler_cxxflags_value()
{
   log_entry "compiler_cxxflags_value" "$@"

   local compiler="$1"
   local configuration="$2"
   local addoptflags="$3"

   local value
   local result
   local name

   result="${OPTION_CXXFLAGS}"
   value="${OPTION_OTHER_CXXFLAGS}"
   result="`concat "$result" "$value"`"

   value="`_compiler_cflags_value "${compiler}" "${configuration}" "${addoptflags}"`"
   result="`concat "$result" "$value"`"

   echo "${result}"
}


compiler_ldflags_value()
{
   log_entry "compiler_ldflags_value" "$@"

   local value
   local result

   result="${OPTION_LDFLAGS}"
   value="${OPTION_OTHER_LDFLAGS}"
   concat "$result" "$value"
}

:
