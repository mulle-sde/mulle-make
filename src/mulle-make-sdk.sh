#! /usr/bin/env bash
#
#   Copyright (c) 2015-2017 Nat! - Mulle kybernetiK
#   All rights reserved.
#
#   Redistribution and use in source and binary forms, with or without
#   modification, are permitted provided that the following conditions are met:
#
#   Redistributions of source code must retain the above copyright notice, this
#   list of conditions and the following disclaimer.
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
MULLE_MAKE_SDK_SH="included"

#
# this should be a plugin based solution
# for now hardcode it
#
r_sdk_arguments()
{
   local plugin="$1"
   local sdk="$2"
   local platform="$3"

   # gets passed in by MULL
   RVAL=
   if [ ! -z "${OPTION_MULLE_SDK_PATH}" ]
   then
      case "${plugin}" in
         cmake)
            RVAL="-DMULLE_SDK_PATH='${OPTION_MULLE_SDK_PATH}'"
         ;;
      esac
   fi

   case "${sdk}" in
      macos*|iphoneos*)
         log_fluff "No special arguments needed for SDK ${sdk}"
         return 0
      ;;

      android*)
         case "${plugin}" in
            cmake)
               RVAL="${RVAL} \
-DANDROID_ABI='${platform}' \
-DANDROID_PLATFORM='${sdk}' \
-DCMAKE_TOOLCHAIN_FILE='\${ANDROID_NDK}/build/cmake/android.toolchain.cmake'"
            ;;
         esac
      ;;
   esac
}