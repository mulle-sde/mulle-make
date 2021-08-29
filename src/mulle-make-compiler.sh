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


# r_platform_c_compiler()
# {
#    log_entry "r_platform_c_compiler" "$@"
#
#    local name
#
#    if [ "${MULLE_FLAG_LOG_SETTINGS}" = 'YES' ]
#    then
#       log_trace2 "CC:  ${DEFINITION_CC}"
#    fi
#
#    name="${DEFINITION_CC}"
#
#    case "${MULLE_UNAME}" in
#       mingw)
#          RVAL="${name:-cl}"
#       ;;
#
#       *)
#          RVAL="${name:-cc}"
#       ;;
#    esac
# }
#
#
# r_platform_cxx_compiler()
# {
#    log_entry "r_platform_cxx_compiler" "$@"
#
#    local name
#
#    if [ "${MULLE_FLAG_LOG_SETTINGS}" = 'YES' ]
#    then
#       log_trace2 "CXX:  ${DEFINITION_CXX}"
#    fi
#
#    name="${DEFINITION_CXX}"
#
#    case "${MULLE_UNAME}" in
#       mingw)
#          RVAL="${name:-cl}"
#       ;;
#
#       *)
#          RVAL="${name:-c++}"
#       ;;
#    esac
# }


#
# assume default is release and the flags
# are set for that
#
_r_compiler_configuration_options()
{
   log_entry "_r_compiler_configuration_options" "$@"

   local name="$1"
   local configuration="$2"

   RVAL=
   case "${name%.*}" in
      cl|*-cl)
         case "${configuration}" in
            Debug|Test)
               RVAL="${OPTION_CL_DEBUG:-/Od /Zi}"
            ;;
         esac
      ;;

      *)
         case "${configuration}" in
            Debug|Test)
               RVAL="${DEFINITION_CC_DEBUG:--g -O0}"
            ;;
         esac
      ;;
   esac
}


#
# this should be part of mulle-platform
#
r_darwin_sdkpath_for_sdk()
{
   local sdk="$1"

   local sdkpath

   if [ "${sdk}" = "Default" ]
   then
      # on 10.6 this will fail as --show-sdk-path ain't there
      sdkpath="`rexekutor xcrun --show-sdk-path 2> /dev/null`"
      if [ -z "${sdkpath}" ]
      then
         # hardcode SDK for now
         sdkpath="`xcode-select  -print-path`" || exit 1
         case "`sw_vers -productVersion 2> /dev/null`" in
            10\.6\.*)
              r_filepath_concat "${sdkpath}" "SDKs/MacOSX10.6.sdk"
            ;;

            *)
               r_filepath_concat "${sdkpath}" "Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk"
            ;;
         esac
         sdkpath="${RVAL}"
         if [ ! -d "${sdkpath}" ]
         then
            fail "Couldn't figure out default SDK"
         fi
      fi
   else
      # on 10.6 this is basically impossible to do
      sdkpath="`rexekutor xcrun --sdk "${sdk}" --show-sdk-path`"
   fi

   if [ "${sdkpath}" = "" ]
   then
      fail "SDK \"${sdk}\" is not installed"
   fi
   RVAL="${sdkpath}"
}


# compiler is re
r_compiler_get_sdkpath()
{
   log_entry "r_compiler_get_sdkpath" "$@"

   local sdk="$1"

   local sdkpath

   RVAL=""

   if [ "${DEFINITION_DETERMINE_SDK}" = 'NO' ]
   then
      return 1
   fi

   case "${MULLE_UNAME}" in
      darwin)
         r_darwin_sdkpath_for_sdk "${sdk}"
      ;;
   esac

   return 0
}


r_default_flag_definer()
{
   RVAL="-D$*"
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

   local flag_definer="${1:-r_default_flag_definer}"

   if [ "${MULLE_FLAG_LOG_SETTINGS}" = 'YES' ]
   then
      log_trace2 "ENV CPPFLAGS:       ${CPPFLAGS}"
      log_trace2 "ENV OTHER_CPPFLAGS: ${OTHER_CPPFLAGS}"
      log_trace2 "CPPFLAGS:           ${DEFINITION_CPPFLAGS}"
      log_trace2 "OTHER_CPPFLAG:      ${DEFINITION_OTHER_CPPFLAGS}"
   fi

   local result 

   if is_plus_key "DEFINITION_CPPFLAGS"
   then
      r_concat "${DEFINITION_CPPFLAGS}" "${CPPFLAGS}"
      result="${RVAL}"
   else
      result="${DEFINITION_CPPFLAGS:-${CPPFLAGS}}"
   fi

   if is_plus_key "DEFINITION_OTHER_CPPFLAGS"
   then
      r_concat "${DEFINITION_OTHER_CPPFLAGS}" "${OTHER_CPPFLAGS}"
      r_concat "${result}" "${RVAL}"
      result="${RVAL}"
   else
      r_concat "${result}" "${DEFINITION_OTHER_CPPFLAGS:-${OTHER_CPPFLAGS}}"
      result="${RVAL}"
   fi

   case "${compiler%.*}" in
      c++|cc|gcc*|*clang*|"")
         if [ "${MULLE_FLAG_LOG_SETTINGS}" = 'YES' ]
         then
            log_trace2 "DEFINITION_GCC_PREPROCESSOR_DEFINITIONS:  ${DEFINITION_GCC_PREPROCESSOR_DEFINITIONS}"
         fi

         local definition

         IFS=","
         shell_disable_glob
         for definition in ${DEFINITION_GCC_PREPROCESSOR_DEFINITIONS}
         do
            "${flag_definer}" "${i}"
            r_concat "${result}" "${RVAL}"
            result="${RVAL}"
         done
         IFS="${DEFAULT_IFS}"
         shell_enable_glob
      ;;
   esac

   RVAL="${result}"
}



_r_compiler_cflags_value()
{
   log_entry "_r_compiler_cflags_value" "$@"

   local compiler="$1"
   local configuration="$2"
   local addoptflags="${3:-YES}"

   if [ "${MULLE_FLAG_LOG_SETTINGS}" = 'YES' ]
   then
      log_trace2 "WARNING_CFLAGS:  ${DEFINITION_WARNING_CFLAGS}"
   fi

   local result

   result="${DEFINITION_WARNING_CFLAGS}"

   if [ "${addoptflags}" = 'YES' ]
   then
      _r_compiler_configuration_options "${compiler}" "${configuration}"
      r_concat "${result}" "${RVAL}"
      result="${RVAL}"
   fi

   RVAL="${result}"
}


r_compiler_cflags_value()
{
   log_entry "r_compiler_cflags_value" "$@"

   local compiler="$1"
   local configuration="$2"
   local addoptflags="$3"

   if [ "${MULLE_FLAG_LOG_SETTINGS}" = 'YES' ]
   then
      log_trace2 "ENV CFLAGS:       ${CFLAGS}"
      log_trace2 "ENV OTHER_CFLAGS: ${OTHER_CFLAGS}"
      log_trace2 "CFLAGS:           ${DEFINITION_CFLAGS}"
      log_trace2 "OTHER_CFLAGS:     ${DEFINITION_OTHER_CFLAGS}"
   fi

   local result

   # DEFINITION_LDFLAGS overrides LDFLAGS except it its += defined
   if is_plus_key "DEFINITION_CFLAGS"
   then
      r_concat "${DEFINITION_CFLAGS}" "${CFLAGS}"
      result="${RVAL}"
   else
      result="${DEFINITION_CFLAGS:-${CFLAGS}}"
   fi

   if is_plus_key "DEFINITION_OTHER_CFLAGS"
   then
      r_concat "${DEFINITION_OTHER_CFLAGS}" "${OTHER_CFLAGS}"
      r_concat "${result}" "${RVAL}"
      result="${RVAL}"
   else
      r_concat "${result}" "${DEFINITION_OTHER_CFLAGS:-${OTHER_CFLAGS}}"
      result="${RVAL}"
   fi

   _r_compiler_cflags_value "${compiler}" "${configuration}" "${addoptflags}"
   r_concat "${result}" "${RVAL}"
}


r_compiler_cxxflags_value()
{
   log_entry "r_compiler_cxxflags_value" "$@"

   local compiler="$1"
   local configuration="$2"
   local addoptflags="$3"


   if [ "${MULLE_FLAG_LOG_SETTINGS}" = 'YES' ]
   then
      log_trace2 "ENV CXXFLAGS:       ${CXXFLAGS}"
      log_trace2 "ENV OTHER_CXXFLAGS: ${OTHER_CXXFLAGS}"
      log_trace2 "CXXFLAGS:           ${DEFINITION_CXXFLAGS}"
      log_trace2 "OTHER_CXXFLAGS:     ${DEFINITION_OTHER_CXXFLAGS}"
   fi

   local result

   # DEFINITION_CXXFLAGS overrides CXXFLAGS except it its += defined
   if is_plus_key "DEFINITION_CXXFLAGS"
   then
      r_concat "${DEFINITION_CXXFLAGS}" "${CXXFLAGS}"
      result="${RVAL}"
   else
      result="${DEFINITION_CXXFLAGS:-${CXXFLAGS}}"
   fi

   if is_plus_key "DEFINITION_OTHER_CXXFLAGS"
   then
      r_concat "${DEFINITION_OTHER_CXXFLAGS}" "${OTHER_CXXFLAGS}"
      r_concat "${result}" "${RVAL}"
      result="${RVAL}"
   else
      r_concat "${result}" "${DEFINITION_OTHER_CXXFLAGS:-${OTHER_CXXFLAGS}}"
      result="${RVAL}"
   fi

   _r_compiler_cflags_value "${compiler}" "${configuration}" "${addoptflags}"
   r_concat "${result}" "${RVAL}"
}


r_compiler_ldflags_value()
{
   log_entry "r_compiler_ldflags_value" "$@"

   local compiler="$1"
   local configuration="$2"


   if [ "${MULLE_FLAG_LOG_SETTINGS}" = 'YES' ]
   then
      log_trace2 "ENV LDFLAGS:       ${LDFLAGS}"
      log_trace2 "ENV OTHER_LDFLAGS: ${OTHER_LDFLAGS}"
      log_trace2 "LDFLAGS:           ${DEFINITION_LDFLAGS}"
      log_trace2 "OTHER_LDFLAGS:     ${DEFINITION_OTHER_LDFLAGS}"
   fi

   local result

   # DEFINITION_LDFLAGS overrides LDFLAGS except it its += defined
   if is_plus_key "DEFINITION_LDFLAGS"
   then
      r_concat "${DEFINITION_LDFLAGS}" "${LDFLAGS}"
      result="${RVAL}"
   else
      result="${DEFINITION_LDFLAGS:-${LDFLAGS}}"
   fi

   if is_plus_key "DEFINITION_OTHER_LDFLAGS"
   then
      r_concat "${DEFINITION_OTHER_LDFLAGS}" "${OTHER_LDFLAGS}"
      r_concat "${result}" "${RVAL}"
      result="${RVAL}"
   else
      r_concat "${result}" "${DEFINITION_OTHER_LDFLAGS:-${OTHER_LDFLAGS}}"
      result="${RVAL}"
   fi

   # doesn't work for me though...
   # https://stackoverflow.com/questions/11731229/dladdr-doesnt-return-the-function-name/11732893?r=SearchResults&s=3|31.5239#11732893
   case "${configuration}" in
      'Debug')
         case "${MULLE_UNAME}" in
            linux)
               case "${compiler%.*}" in
                  *gcc|*clang)
                     r_concat "${result}" "-Wl,--export-dynamic"
                     result="${RVAL}"
                  ;;
               esac
            ;;
         esac
      ;;
   esac

   RVAL="${result}"
}


r_compiler_cmakeflags_values()
{
   log_entry "r_compiler_cmakeflags_values" "$@"

   local compiler="$1"
   local configuration="$2"

   RVAL=""
   case "${compiler}" in
      *tcc)
         headerpath="`mulle-platform includepath --cmake`"
         RVAL="-DCMAKE_C_COMPILER_WORKS=ON
-DCMAKE_C_STANDARD_INCLUDE_DIRECTORIES=${headerpath}
-DHAVE_FLAG_SEARCH_PATHS_FIRST=OFF
-DHAVE_HEADERPAD_MAX_INSTALL_NAMES=OFF"

      ;;
   esac
}

:
