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


r_platform_c_compiler()
{
   local name

   if [ "${MULLE_FLAG_LOG_SETTINGS}" = "YES" ]
   then
      log_trace2 "CC:  ${OPTION_CC}"
   fi

   name="${OPTION_CC}"

   case "${MULLE_UNAME}" in
      mingw)
         RVAL="${name:-cl}"
      ;;

      *)
         RVAL="${name:-cc}"
      ;;
   esac
}


r_platform_cxx_compiler()
{
   local name

   if [ "${MULLE_FLAG_LOG_SETTINGS}" = "YES" ]
   then
      log_trace2 "CXX:  ${OPTION_CXX}"
   fi

   name="${OPTION_CXX}"

   case "${MULLE_UNAME}" in
      mingw)
         RVAL="${name:-cl}"
      ;;

      *)
         RVAL="${name:-c++}"
      ;;
   esac
}


#
# assume default is release and the flags
# are set for that
#
_r_compiler_debug_options()
{
   local name="$1"

   case "${name%.*}" in
      cl|*-cl)
         RVAL="/Od /Zi"
      ;;

      *)
         RVAL="-g -O0"
      ;;
   esac
}


# compiler is re
r_compiler_sdk_parameter()
{
   local sdk="$1"

   local sdkpath

   RVAL=""

   if [ "${OPTION_DETERMINE_SDK}" = "NO" ]
   then
      return
   fi

   case "${MULLE_UNAME}" in
      darwin)
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
         RVAL="${sdkpath}"
      ;;
   esac
}


#
# Mash some known settings from xcodebuild together for regular
# OTHER_CFLAGS
# WARNING_CFLAGS
# COMPILER_PREPROCESSOR_DEFINITIONS
#
# The -I/-isystem generation s done somewhere else
#
r_compiler_cppflags_value()
{
   log_entry "r_compiler_cppflags_value" "$@"

   if [ "${MULLE_FLAG_LOG_SETTINGS}" = "YES" ]
   then
      log_trace2 "CPPFLAGS:       ${OPTION_CPPFLAGS}"
      log_trace2 "OTHER_CPPFLAG:  ${OPTION_OTHER_CPPFLAGS}"
   fi

   r_concat "${OPTION_CPPFLAGS}" "${OPTION_OTHER_CPPFLAGS}"

   case "${compiler%.*}" in
      c++|cc|gcc*|*clang*|"")
         if [ "${MULLE_FLAG_LOG_SETTINGS}" = "YES" ]
         then
            log_trace2 "OPTION_GCC_PREPROCESSOR_DEFINITIONS:  ${OPTION_GCC_PREPROCESSOR_DEFINITIONS}"
         fi

         IFS=","
         set -o noglob
         for i in ${OPTION_GCC_PREPROCESSOR_DEFINITIONS}
         do
            r_concat "${RVAL}" "-D${i}"
         done
         IFS="${DEFAULT_IFS}"
         set +o noglob
      ;;
   esac
}


_r_compiler_cflags_value()
{
   local compiler="$1"
   local configuration="$2"
   local addoptflags="${3:-YES}"

   local value
   local result
   local i

   if [ "${MULLE_FLAG_LOG_SETTINGS}" = "YES" ]
   then
      log_trace2 "WARNING_CFLAGS:  ${OPTION_WARNING_CFLAGS}"
   fi

   result="${OPTION_WARNING_CFLAGS}"

   if [ "${addoptflags}" = "YES" ]
   then
      case "${configuration}" in
         Debug)
            _r_compiler_debug_options "${compiler}"
            r_concat "$result" "${RVAL}"
            result="${RVAL}"
         ;;
      esac
   fi

   RVAL="${result}"
}


r_compiler_cflags_value()
{
   log_entry "r_compiler_cflags_value" "$@"

   local compiler="$1"
   local configuration="$2"
   local addoptflags="$3"

   local result

   if [ "${MULLE_FLAG_LOG_SETTINGS}" = "YES" ]
   then
      log_trace2 "CFLAGS:          ${OPTION_CFLAGS}"
      log_trace2 "OTHER_CFLAGS:    ${OPTION_OTHER_CFLAGS}"
   fi

   r_concat "${OPTION_CFLAGS}" "${OPTION_OTHER_CFLAGS}"
   result="${RVAL}"

   _r_compiler_cflags_value "${compiler}" "${configuration}" "${addoptflags}"
   r_concat "${result}" "${RVAL}"

   RVAL="${result}"
}


r_compiler_cxxflags_value()
{
   log_entry "r_compiler_cxxflags_value" "$@"

   local compiler="$1"
   local configuration="$2"
   local addoptflags="$3"

   local result

   if [ "${MULLE_FLAG_LOG_SETTINGS}" = "YES" ]
   then
      log_trace2 "CXXFLAGS:        ${OPTION_CXXFLAGS}"
      log_trace2 "OTHER_CXXFLAGS:  ${OPTION_OTHER_CXXFLAGS}"
   fi

   r_concat "${OPTION_CXXFLAGS}" "${OPTION_OTHER_CXXFLAGS}"
   result="${RVAL}"

   _r_compiler_cflags_value "${compiler}" "${configuration}" "${addoptflags}"
   r_concat "${result}" "${RVAL}"
}


r_compiler_ldflags_value()
{
   log_entry "r_compiler_ldflags_value" "$@"

   if [ "${MULLE_FLAG_LOG_SETTINGS}" = "YES" ]
   then
      log_trace2 "LDFLAGS:         ${OPTION_LDFLAGS}"
      log_trace2 "OTHER_LDFLAGS:   ${OPTION_OTHER_LDFLAGS}"
   fi

   r_concat "${OPTION_LDFLAGS}" "${OPTION_OTHER_LDFLAGS}"
}

:
