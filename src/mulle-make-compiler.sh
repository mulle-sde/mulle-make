# shellcheck shell=bash
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
MULLE_MAKE_COMPILER_SH='included'


# r_platform_c_compiler()
# {
#    log_entry "r_platform_c_compiler" "$@"
#
#    local name
#
#    if [ "${MULLE_FLAG_LOG_SETTINGS}" = 'YES' ]
#    then
#       log_setting "CC:  ${DEFINITION_CC}"
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
#       log_setting "CXX:  ${DEFINITION_CXX}"
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
make::compiler::r_configuration_options()
{
   log_entry "make::compiler::r_configuration_options" "$@"

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
make::compiler::r_darwin_sdkpath_for_sdk()
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
make::compiler::r_get_sdkpath()
{
   log_entry "make::compiler::r_get_sdkpath" "$@"

   local sdk="$1"

   local sdkpath

   RVAL=""

   if [ "${DEFINITION_DETERMINE_SDK}" = 'NO' ]
   then
      return 1
   fi

   case "${MULLE_UNAME}" in
      darwin)
         make::compiler::r_darwin_sdkpath_for_sdk "${sdk}"
      ;;
   esac

   return 0
}


make::compiler::r_default_flag_definer()
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
make::compiler::r_cppflags_value()
{
   log_entry "make::compiler::r_cppflags_value" "$@"

   local flag_definer="${1:-make::compiler::r_default_flag_definer}"

   log_setting "ENV CPPFLAGS:       ${CPPFLAGS}"
   log_setting "ENV OTHER_CPPFLAGS: ${OTHER_CPPFLAGS}"
   log_setting "CPPFLAGS:           ${DEFINITION_CPPFLAGS}"
   log_setting "OTHER_CPPFLAG:      ${DEFINITION_OTHER_CPPFLAGS}"

   local result 

   if make::definition::is_plus_key "DEFINITION_CPPFLAGS"
   then
      r_concat "${DEFINITION_CPPFLAGS}" "${CPPFLAGS}"
      result="${RVAL}"
   else
      result="${DEFINITION_CPPFLAGS:-${CPPFLAGS}}"
   fi

   if make::definition::is_plus_key "DEFINITION_OTHER_CPPFLAGS"
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
         log_setting "DEFINITION_GCC_PREPROCESSOR_DEFINITIONS:  ${DEFINITION_GCC_PREPROCESSOR_DEFINITIONS}"

         local definition

         .foreachitem definition in ${DEFINITION_GCC_PREPROCESSOR_DEFINITIONS}
         .do
            "${flag_definer}" "${i}"
            r_concat "${result}" "${RVAL}"
            result="${RVAL}"
         .done
      ;;
   esac

   RVAL="${result}"
}


make::compiler::_r_cflags_value()
{
   log_entry "make::compiler::_r_cflags_value" "$@"

   local compiler="$1"
   local configuration="$2"
   local addoptflags="${3:-YES}"

   if [ "${MULLE_FLAG_LOG_SETTINGS}" = 'YES' ]
   then
      log_setting "WARNING_CFLAGS:  ${DEFINITION_WARNING_CFLAGS}"
   fi

   local result

   result="${DEFINITION_WARNING_CFLAGS}"

   if [ "${addoptflags}" = 'YES' ]
   then
      make::compiler::r_configuration_options "${compiler}" "${configuration}"
      r_concat "${result}" "${RVAL}"
      result="${RVAL}"
   fi

   RVAL="${result}"
}


make::compiler::r_cflags_value()
{
   log_entry "make::compiler::r_cflags_value" "$@"

   local compiler="$1"
   local configuration="$2"
   local addoptflags="$3"

   log_setting "ENV CFLAGS:       ${CFLAGS}"
   log_setting "ENV OTHER_CFLAGS: ${OTHER_CFLAGS}"
   log_setting "CFLAGS:           ${DEFINITION_CFLAGS}"
   log_setting "OTHER_CFLAGS:     ${DEFINITION_OTHER_CFLAGS}"

   local result

   # DEFINITION_CFLAGS is already initialized from CFLAGS at startup
   # For xcode-additive (plus key), add environment on top
   if make::definition::is_plus_key "DEFINITION_CFLAGS"
   then
      r_concat "${DEFINITION_CFLAGS}" "${CFLAGS}"
      result="${RVAL}"
   else
      result="${DEFINITION_CFLAGS}"
   fi

   if make::definition::is_plus_key "DEFINITION_OTHER_CFLAGS"
   then
      r_concat "${DEFINITION_OTHER_CFLAGS}" "${OTHER_CFLAGS}"
      r_concat "${result}" "${RVAL}"
      result="${RVAL}"
   else
      r_concat "${result}" "${DEFINITION_OTHER_CFLAGS}"
      result="${RVAL}"
   fi

   make::compiler::_r_cflags_value "${compiler}" "${configuration}" "${addoptflags}"
   r_concat "${result}" "${RVAL}"
}


make::compiler::r_cxxflags_value()
{
   log_entry "make::compiler::r_cxxflags_value" "$@"

   local compiler="$1"
   local configuration="$2"
   local addoptflags="$3"

   log_setting "ENV CXXFLAGS:       ${CXXFLAGS}"
   log_setting "ENV OTHER_CXXFLAGS: ${OTHER_CXXFLAGS}"
   log_setting "CXXFLAGS:           ${DEFINITION_CXXFLAGS}"
   log_setting "OTHER_CXXFLAGS:     ${DEFINITION_OTHER_CXXFLAGS}"

   local result

   # DEFINITION_CXXFLAGS is already initialized from CXXFLAGS at startup
   if make::definition::is_plus_key "DEFINITION_CXXFLAGS"
   then
      r_concat "${DEFINITION_CXXFLAGS}" "${CXXFLAGS}"
      result="${RVAL}"
   else
      result="${DEFINITION_CXXFLAGS}"
   fi

   if make::definition::is_plus_key "DEFINITION_OTHER_CXXFLAGS"
   then
      r_concat "${DEFINITION_OTHER_CXXFLAGS}" "${OTHER_CXXFLAGS}"
      r_concat "${result}" "${RVAL}"
      result="${RVAL}"
   else
      r_concat "${result}" "${DEFINITION_OTHER_CXXFLAGS}"
      result="${RVAL}"
   fi

   make::compiler::_r_cflags_value "${compiler}" "${configuration}" "${addoptflags}"
   r_concat "${result}" "${RVAL}"
}


make::compiler::r_ldflags_value()
{
   log_entry "make::compiler::r_ldflags_value" "$@"

   local compiler="$1"
   local configuration="$2"

   log_setting "ENV LDFLAGS:       ${LDFLAGS}"
   log_setting "ENV OTHER_LDFLAGS: ${OTHER_LDFLAGS}"
   log_setting "LDFLAGS:           ${DEFINITION_LDFLAGS}"
   log_setting "OTHER_LDFLAGS:     ${DEFINITION_OTHER_LDFLAGS}"

   local result

   # DEFINITION_LDFLAGS is already initialized from LDFLAGS at startup
   if make::definition::is_plus_key "DEFINITION_LDFLAGS"
   then
      r_concat "${DEFINITION_LDFLAGS}" "${LDFLAGS}"
      result="${RVAL}"
   else
      result="${DEFINITION_LDFLAGS}"
   fi

   if make::definition::is_plus_key "DEFINITION_OTHER_LDFLAGS"
   then
      r_concat "${DEFINITION_OTHER_LDFLAGS}" "${OTHER_LDFLAGS}"
      r_concat "${result}" "${RVAL}"
      result="${RVAL}"
   else
      r_concat "${result}" "${DEFINITION_OTHER_LDFLAGS}"
      result="${RVAL}"
   fi

   #
   # doesn't work for me though...
   # https://stackoverflow.com/questions/11731229/dladdr-doesnt-return-the-function-name/11732893?r=SearchResults&s=3|31.5239#11732893
   #
   # MEMO: commented this out, because it's not wanted in every case
   #       (-> cosmopolitan), also not sure if this is still needed
   #
   #   case "${configuration}" in
   #      'Debug'|'Test')
   #         case "${MULLE_UNAME}" in
   #            linux)
   #               case "${compiler%.*}" in
   #                  *gcc|*clang)
   #                     r_concat "${result}" "-Wl,--export-dynamic"
   #                     result="${RVAL}"
   #                  ;;
   #               esac
   #            ;;
   #         esac
   #      ;;
   #   esac

   RVAL="${result}"
}



make::compiler::r_value_for_keys()
{
   local key

   while [ $# -ne 0 ]
   do
      key="$1"
      shift

      r_shell_indirect_expand "${key}"
      if [ ! -z "${RVAL}" ]
      then
         log_debug "${key}=${RVAL} found"
         return 0
      fi
   done

   RVAL=
   return 1
}


#
# Support overriding c-compilers better.
#
# gcc for C, mulle-clang for Objective-C, but then also variants like
# gcc.musl and mulle-clang.cosmpolitan. We may need to build some parts
# with "gcc" only and some parts with gcc.musl and some with
# mulle-clang.musl.
#
# Old Scheme:
# cmakes pick is the default
# DEFINITION_CC is what the project wants (important: switch to ObjC implied)
# $ENV{CC} overrides DEFINITION_CC
#
# New Scheme:
#
# Make it possible to change the new order
# Add DEFINITION:PREFER_ENV_CC definition set to NO, so that a project that really
# wants only the value set in DEFINITION_CC.
#
# ``` bash
# mulle-sde definition set CC gcc
# mulle-sde definition set DEFINITION_PREFER_ENV_CC NO
# ```
make::compiler::r_cc_compiler()
{
   log_entry "make::compiler::r_cc_compiler" "$@"

   RVAL=

   local selection

   selection="${DEFINITION_SELECT_CC:-environment,definition}"
   log_debug "selection: ${selection}"

   case ",${selection}," in
      *',definition,environment,'*)
         make::compiler::r_value_for_keys 'DEFINITION_CC' 'CC'
      ;;

      *',environment,definition,'*)
         make::compiler::r_value_for_keys 'CC' 'DEFINITION_CC'
      ;;

      *',environment,'*)
         make::compiler::r_value_for_keys 'CC'
      ;;

      *',definition,'*)
         make::compiler::r_value_for_keys 'DEFINITION_CC'
      ;;

      *',clobber,'*)
         CC=
         export CC
         log_debug "CC set to empty"
      ;;

      *',none,'*)
      ;;

      *)
         fail "invalid value \"${DEFINITION_SELECT_CC}\" for DEFINITION_SELECT_CC (environment, definition, clobber, none, no-fallback))"
      ;;
   esac

   case "${RVAL}" in
      *zig\ cc*)
         log_warning "Use \"zig;cc\" not \"zig cc\" to specify zig as the C compiler"
      ;;
   esac

   log_fluff "C compiler is ${RVAL:-system default}"
}


make::compiler::r_cobjc_compiler()
{
   local selection

   selection="${DEFINITION_SELECT_COBJC:-environment,definition}"
   log_debug "selection: ${selection}"

   case ",${selection}," in
      *',definition,environment,'*)
         make::compiler::r_value_for_keys 'DEFINITION_COBJC' 'COBJC'
      ;;

      *',environment,definition,'*)
         make::compiler::r_value_for_keys 'COBJC' 'DEFINITION_COBJC'
      ;;

      *',environment,'*)
         make::compiler::r_value_for_keys 'COBJC'
      ;;

      *',definition,'*)
         make::compiler::r_value_for_keys 'DEFINITION_COBJC'
      ;;

      *',clobber,'*)
         COBJC=
         export COBJC
         log_debug "COBJC set to empty"
      ;;

      *',none,'*)
      ;;

      *)
         fail "invalid value \"${DEFINITION_SELECT_COBJC}\" for DEFINITION_SELECT_COBJC (environment, definition, clobber, none, no-fallback))"
      ;;
   esac

   [ ! -z "${RVAL}" ]
}


make::compiler::r_c_compiler()
{
   log_entry "make::compiler::r_c_compiler" "$@"

   local language
   local dialect
   local selection

   language="${DEFINITION_PROJECT_LANGUAGE:-c}"
   log_debug "language: ${language}"

   RVAL=
   case "${language}" in
      [cC])
         #
         # use DEFINITION_CC as a hint, for objc
         # don't use c_compiler here
         #
         # case "${DEFINITION_COBJC}" in
         #    *mulle-clang*)
         #       c_dialect="objc"
         #    ;;
         # esac

         r_lowercase "${DEFINITION_PROJECT_DIALECT:-${dialect}}"
         dialect="${RVAL}"

         log_debug "dialect: ${dialect}"

         RVAL=
         case "${dialect}" in
            'objc'|'obj-c'|'objective-c'|'objectivec')
               if make::compiler::r_cobjc_compiler
               then
                  return
               fi
               case ",${DEFINITION_SELECT_COBJC}," in
                  *,no-fallback,*)
                     log_fluff "No fallback and no objc compiler set"
                     return 1
                  ;;
               esac
            ;;
         esac

         make::compiler::r_cc_compiler
      ;;
   esac
}


make::compiler::r_cxx_compiler()
{
   log_entry "make::compiler::r_cxx_compiler" "$@"

   RVAL=
   case ",${DEFINITION_SELECT_CXX:-environment,definition}," in
      *',definition,environment,'*)
         make::compiler::r_value_for_keys 'DEFINITION_CXX' 'CXX'
      ;;

      *',environment,definition,'*)
         make::compiler::r_value_for_keys 'CXX' 'DEFINITION_CXX'
      ;;

      *',environment,'*)
         make::compiler::r_value_for_keys 'CXX'
      ;;

      *',definition,'*)
         make::compiler::r_value_for_keys 'DEFINITION_CXX'
      ;;

      *',clobber,'*)
         CXX=
         export CXX
         log_debug "CXX set to empty"
      ;;

      *',none,'*)
      ;;

      *)
         fail "invalid value \"${DEFINITION_SELECT_CXX}\" for DEFINITION_SELECT_CXX (environment, definition, clobber, none, no-fallback))"
      ;;
   esac

   if [ -z "${RVAL}" ]
   then
      case ",${DEFINITION_SELECT_CXX}," in
         *,no-fallback,*)
            log_fluff "No fallback and no c++ compiler set"
            return
         ;;
      esac

      make::compiler::r_c_compiler
   fi

   log_fluff "c++ compiler set to ${RVAL}"
}


# useful for some tool selection, oif you know you want C usr r_c_compiler direct
make::compiler::r_compiler()
{
   RVAL=
   case "${DEFINITION_PROJECT_LANGUAGE:-c}" in
      'c')
         make::compiler::r_c_compiler
      ;;

      'cxx'|'c++'|'cpp'|'cplusplus')
         make::compiler::r_cxx_compiler
      ;;
   esac
}


make::compiler::r_cmakeflags_values()
{
   log_entry "make::compiler::r_cmakeflags_values" "$@"

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
