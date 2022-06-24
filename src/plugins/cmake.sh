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
MULLE_MAKE_PLUGIN_CMAKE_SH="included"


make::plugin::cmake::r_platform_cmake_generator()
{
   log_entry "make::plugin::cmake::r_platform_cmake_generator" "$@"

   local makepath="$1"
   local name

   r_basename "${makepath}"
   name="${RVAL}"

   case "${name%.*}" in
      nmake)
         RVAL="NMake Makefiles"
      ;;

      mingw*|MINGW*)
         RVAL="MinGW Makefiles"
      ;;

      ninja)
         RVAL="Ninja"
      ;;

      *)
         case "${MULLE_UNAME}" in
            mingw*)
               RVAL="MSYS Makefiles"
            ;;

            *)
               RVAL="Unix Makefiles"
            ;;
         esac
      ;;
   esac

   log_fluff "Using ${RVAL} as cmake generator"
}


make::plugin::cmake::r_find_cmake()
{
   log_entry "make::plugin::cmake::r_find_cmake" "$@"

   local toolname
   local tooldefaultname

   tooldefaultname="cmake${MULLE_EXE_EXTENSION}"
   toolname="${DEFINITION_CMAKE:-${CMAKE:-${tooldefaultname}}}"
   make::command::r_verify_binary "${toolname}" "cmake" "${tooldefaultname}"
}


make::plugin::cmake::tools_environment()
{
   log_entry "make::plugin::cmake::tools_environment" "$@"

   make::common::tools_environment

   local defaultgenerator

   make::plugin::cmake::r_find_cmake
   CMAKE="${RVAL}"

   make::common::r_make_for_plugin "cmake" ""
   MAKE="${RVAL}"

   make::plugin::cmake::r_platform_cmake_generator "${MAKE}"
   defaultgenerator="${RVAL}"

   CMAKE_GENERATOR="${DEFINITION_CMAKE_GENERATOR:-${defaultgenerator}}"

}


make::plugin::cmake::r_cmakeflags_add_sdk_parameter()
{
   log_entry "make::plugin::cmake::r_cmakeflags_add_sdk_parameter" "$@"

   local cmakeflags="$1"
   local sdk="$2"

   if [ "${DEFINITION_DETERMINE_SDK}" != 'NO' ]
   then
      case "${MULLE_UNAME}" in
         "darwin")
            make::compiler::r_get_sdkpath "${sdk}"
            if [ ! -z "${RVAL}" ]
            then
               make::plugin::cmake::r_cmakeflags_add_flag "${cmakeflags}" "CMAKE_OSX_SYSROOT" "${RVAL}"
               return
            fi
         ;;
      esac
   fi

   RVAL="${cmakeflags}"
}


#
# this should be a plugin based solution
# for now hardcode it
#
make::plugin::cmake::r_cmake_sdk_arguments()
{
   log_entry "make::plugin::cmake::r_cmake_sdk_arguments" "$@"

   local cmakeflags="$1"
   local sdk="$2"
   local platform="$3"

   RVAL="${cmakeflags}"

   case "${sdk}" in
      macos*)
      ;;

      # stuff won't compile unless ARCHS is specified for iphoneos
      # architectures are somewhat dependent on SDK and baselines
      # its complicated:
      # See: https://github.com/leetal/ios-cmake/blob/master/ios.toolchain.cmake
      #
      iphoneos*)
         make::plugin::cmake::r_cmakeflags_add_flag "${RVAL}" \
                               "CMAKE_OSX_ARCHITECTURES" \
                               "armv7;armv7s;arm64;arm64e"
      ;;

      iphonesimulator*)
         make::plugin::cmake::r_cmakeflags_add_flag "${RVAL}" \
                               "CMAKE_OSX_ARCHITECTURES" \
                               "x86_64"
      ;;

      android*)
         make::plugin::cmake::r_cmakeflags_add_flag "${RVAL}" \
                               "CMAKE_TOOLCHAIN_FILE" \
                               "\${ANDROID_NDK}/build/cmake/android.toolchain.cmake"
      ;;
   esac
}


make::plugin::cmake::cmake_files_are_newer_than_makefile()
{
   log_entry "make::plugin::cmake::cmake_files_are_newer_than_makefile" "$@"

   local absprojectdir="$1"
   local makefile="$2"

   MULLE_MATCH_PATH="${MULLE_MATCH_PATH:-${MULLE_MATCH_PATH}}"

   if [ -z "${MULLE_MATCH_PATH}" ]
   then
      log_debug "MULLE_MATCH_PATH is undefined, so run cmake"
      return 0
   fi

   if [ ! -f "${makefile}" ]
   then
      log_debug "Makefile \"${makefile}\" not found, so run cmake"
      return 0
   fi

   local arguments
   local location

   IFS=':'
   for location in ${MULLE_MATCH_PATH}
   do
      [ -z "${location}" ] && fail "Environment variable \
MULLE_MATCH_PATH must not contain empty paths"

      if ! is_absolutepath "${location}"
      then
         location="${absprojectdir}/${location}"
      fi
      if [ -e "${location}" ]
      then
         r_concat "${arguments}" "${location}"
         arguments="${RVAL}"
      fi
   done
   IFS="${DEFAULT_IFS}"

   if [ -z "${arguments}" ]
   then
      log_debug "No location of MULLE_MATCH_PATH exists"
      return 0
   fi

   arguments="${arguments} \\( -name CMakeLists.txt -o -name '*.cmake' \\)"
   arguments="${arguments} -newer '${makefile}'"

   matches="`eval_exekutor "find" "${arguments}"`"
   log_debug "cmakefiles with changes: [${matches}]"

   [ ! -z "${matches}" ]
}


make::plugin::cmake::debug_cmake()
{
   echo ">>>" >&2
   for i in "$@"
   do
     printf "%s\n" "$i"  >&2
   done
   echo "<<<"  >&2
}


make::plugin::cmake::r_cmakeflags_add_flag()
{
   local cmakeflags="$1"
   local flag="$2"
   local value="$3"

   r_escaped_singlequotes "${value}"
   r_escaped_shell_string "-D${flag}=${RVAL}"
   r_concat "${cmakeflags}" "${RVAL}"
}


make::plugin::cmake::r_cmakeflags_add()
{
   local cmakeflags="$1"
   local value="$2"

   if [ -z "${value}" ]
   then
      RVAL="${cmakeflags}"
      return
   fi

   r_escaped_shell_string "${value}"
   r_concat "${cmakeflags}" "${RVAL}"
}


make::plugin::cmake::r_cmakeflags_add_toolflags()
{
   log_entry "make::plugin::cmake::r_cmakeflags_add_toolflags" "$@"

   local cmakeflags="$1"
   local flag="$2"
   local value="$3"

   if [ -z "${value}" ]
   then
      RVAL="${cmakeflags}"
      return
   fi

   r_escaped_singlequotes "${value}"
   r_escaped_singlequotes "${RVAL}"
   r_escaped_shell_string "-D${flag}=${RVAL}"
   r_concat "${cmakeflags}" "${RVAL}"
}


#
# defined for xcodebuild by default (\$(inherited))
#
make::plugin::cmake::r_userdefined_definitions()
{
   log_entry "make::plugin::cmake::r_userdefined_definitions" "$@"

   local buildsettings
   local value

   if [ "${pluspref}" = "-" ]
   then
      pluspref=""
   fi

   #
   # only emit UNKNOWN keys, the known keys are handled
   # by the plugins themselves
   #
   keys="`make::definition::all_userdefined_unknown_keys`"

   local key
   local value
   local cmakevalue
   local cmakeflags

   .foreachline key in ${keys}
   .do
      if [ ${ZSH_VERSION+x} ]
      then
         value="${(P)key}"
      else
         value="${!key}"
      fi
      r_escaped_shell_string "${value}"

      # change to cmake separator
      # on MINGW though, this will prohibit escaping so we have to do it manually
      case "${value}" in 
         *:*)
            case "${key}" in
               *_PATH|*_FILES|*_DIRS)
                  case "${MULLE_UNAME}" in 
                     mingw|windows)
                        local filepath 
                        local translatepath

                        # on mingw we always expect cmake.exe
                        # on wsl, we gotta check which it is
                        if [ "${MULLE_UNAME}" = "mingw" ]
                        then 
                           translatepath="cygpath"
                        else 
                           case "${CMAKE}" in 
                              *.exe)
                                 include "platform::wsl"

                                 translatepath="platform::wsl::wslpath"
                              ;;
                           esac
                        fi

                        if [ ! -z "${translatepath}" ]
                        then
                           .foreachpath filepath in ${value}
                           .do
                              # wslpath complains if path is not there, stupid
                              filepath="`${translatepath} -w "${filepath}"`"
                              r_semicolon_concat "${cmakevalue}" "${filepath}"
                              cmakevalue="${RVAL}"
                           .done
                        fi
                     ;;

                     *)
                        cmakevalue="${value//:/;}"
                     ;;
                  esac
                  log_debug "Change ${key} value \"${value}\" to \"${cmakevalue}\""
                  value="${cmakevalue}"
               ;;
            esac
         ;;
      esac
      make::plugin::cmake::r_cmakeflags_add_flag "${cmakeflags}" "${key#DEFINITION_}" "${value}"
      cmakeflags="${RVAL}"
   .done

   RVAL="${cmakeflags}"

   log_debug "User cmake definition: ${RVAL}"
}


#
# If we pass command line parameters to cmake or ninja,
# we are compiling for a windows filesystem. Those tools
# can't deal with /mnt/d, but expect d:
#
make::plugin::cmake::r_convert_path_to_native()
{
   case "${MULLE_UNAME}" in
      windows)
         RVAL="`sed 's|/mnt/\([a-z]\)/|\1:/|g' <<< "$1"`"
      ;;

      *)
         RVAL="$1"
      ;;
   esac
}


#
# remove old kitchendir, create a new one
# depending on configuration cmake with flags
# build stuff into dependencies
# TODO: cache commandline in a file $ and emit instead of rebuilding it every time
#
make::plugin::cmake::build()
{
   log_entry "make::plugin::cmake::build" "$@"

   [ $# -ge 9 ] || _internal_fail "api error"

   local cmd="$1"
   local projectfile="$2"
   local sdk="$3"
   local platform="$4"
   local configuration="$5"
   local srcdir="$6"
   local dstdir="$7"
   local kitchendir="$8"
   local logsdir="$9"

   shift 9

   [ -z "${cmd}" ] && _internal_fail "cmd is empty"
   [ -z "${projectfile}" ] && _internal_fail "projectfile is empty"
   [ -z "${configuration}" ] && _internal_fail "configuration is empty"
   [ -z "${platform}" ] && _internal_fail "platform is empty"
   [ -z "${srcdir}" ] && _internal_fail "srcdir is empty"
   [ -z "${kitchendir}" ] && _internal_fail "kitchendir is empty"
   [ -z "${logsdir}" ] && _internal_fail "logsdir is empty"
   [ -z "${sdk}" ] && _internal_fail "sdk is empty"

   # CMAKE=make::plugin::cmake::debug_cmake

   # need this now
   mkdir_if_missing "${kitchendir}"

   local cflags
   local cxxflags
   local cppflags
   local ldflags

   local cc
   local cxx

   #
   # if we are analyzing we don't want to clobber override CC because its
   # the analyzer...
   if [ "${OPTION_ANALYZE}" = 'YES' ]
   then
      log_info "Using ${CC} and ${CXX} from environment for analyzer run"
      cc="${CC}"
      cxx="${CXX}}"
      [ -z "${cc}" ] && fail "mulle-make with --analyze expects environment CC to be set"
      DEFINITION_CC=
      DEFINITION_CXX=

#      if [ "${MULLE_FLAG_LOG_VERBOSE}" = 'YES' ]
#      then
         export CCC_ANALYZER_VERBOSE=1 # verbose
#      fi
   else
      cc="${DEFINITION_CC:-${CC}}"
      cxx="${DEFINITION_CXX:-${CXX:-${cc}}}"
   fi

   #
   # We are clobbering the CMAKE_C_FLAGS variable, which means that cmake will
   # not pickup CFLAGS. What we do here is look of DEFINITION_CFLAGS is defined and
   # if yes, use it, otherwise use environment CFLAGS as initial value.
   #
   # https://cmake.org/cmake/help/latest/variable/CMAKE_LANG_FLAGS.html#variable:CMAKE_%3CLANG%3E_FLAGS

   make::compiler::r_cflags_value "${cc}" "${configuration}" 'NO'
   cflags="${RVAL}"

   case "${DEFINITION_PROJECT_LANGUAGE}" in
      [cC]|[oO][bB][jJ]*[cC])
         make::compiler::r_cxxflags_value "${cxx}" "${configuration}" 'NO'
         cxxflags="${RVAL}"
      ;;
   esac

   make::compiler::r_cppflags_value "${cc}" "${configuration}"
   cppflags="${RVAL}"
   make::compiler::r_ldflags_value "${cc}" "${configuration}"
   ldflags="${RVAL}"

   # this produces quoted output for
   #  cflags
   #  cppflags
   #  cxxflags
   #  ldflags
   #

   #
   # make::common::r_sdkpath_tool_flags for platforms other than macos
   # where we are using CMAKE_OSX_SYSROOT
   #
   case "${MULLE_UNAME}" in
      darwin)
      ;;

      *)
         local sdkflags

         make::common::r_sdkpath_tool_flags "${sdk}"
         sdkflags="${RVAL}"
         r_concat "${cppflags}" "${sdkflags}"
         cppflags="${RVAL}"
         r_concat "${ldflags}" "${sdkflags}"
         ldflags="${RVAL}"
      ;;
   esac

   make::common::r_headerpath_preprocessor_flags
   r_concat "${cppflags}" "${RVAL}"
   cppflags="${RVAL}"

   make::common::r_librarypath_linker_flags
   r_concat "${ldflags}" "${RVAL}"
   ldflags="${RVAL}"

   #
   # basically adds some flags for android based on chosen SDK
   #
   make::sdk::r_cflags "${sdk}" "${platform}"
   r_concat "${cflags}" "${RVAL}"
   cflags="${RVAL}"

   # cmake has no CMAKE_CPP_FLAGS so we have to merge them into CMAKE_C_CFLAGS

   if [ ! -z "${cppflags}" ]
   then
      r_concat "${cflags}" "${cppflags}"
      cflags="${RVAL}"

      if [ "${DEFINITION_PROJECT_LANGUAGE}" != "c" ]
      then
         r_concat "${cxxflags}" "${cppflags}"
         cxxflags="${RVAL}"
      fi
   fi

   local absbuilddir
   local absprojectdir
   local projectdir

   r_dirname "${projectfile}"
   projectdir="${RVAL}"
   r_simplified_absolutepath "${projectdir}"
   absprojectdir="${RVAL}"
   r_simplified_absolutepath "${kitchendir}"
   absbuilddir="${RVAL}"

   case "${MULLE_UNAME}" in
      mingw*)
         projectdir="${absprojectdir}"
      ;;

      *)
         make::common::r_projectdir_relative_to_builddir "${absbuilddir}" "${absprojectdir}"
         projectdir="${RVAL}"
      ;;
   esac

   log_setting "cflags:        ${cflags}"
   log_setting "cppflags:      ${cppflags}"
   log_setting "cxxflags:      ${cxxflags}"
   log_setting "ldflags:       ${ldflags}"
   log_setting "projectfile:   ${projectfile}"
   log_setting "projectdir:    ${projectdir}"
   log_setting "absprojectdir: ${absprojectdir}"
   log_setting "absbuilddir:   ${absbuilddir}"
   log_setting "projectdir:    ${projectdir}"

   local cmakeflags

   cmakeflags="${DEFINITION_CMAKEFLAGS}"

   log_setting "PREFIX:        ${dstdir}"
   log_setting "PHASE:         ${OPTION_PHASE}"
   log_setting "CMAKEFLAGS:    ${DEFINITION_CMAKEFLAGS}"

   #
   # this should export a compile_commands.json command, which
   # by default should be helpful
   #
   if [ "${DEFINITION_CMAKE_COMPILE_COMMANDS}" != 'NO' ]
   then
      make::plugin::cmake::r_cmakeflags_add_flag "${cmakeflags}" "CMAKE_EXPORT_COMPILE_COMMANDS" "ON"
      cmakeflags="${RVAL}"
   fi

   if [ "${MULLE_FLAG_LOG_VERBOSE}" != 'YES' ]
   then
      make::plugin::cmake::r_cmakeflags_add "${cmakeflags}" "--no-warn-unused-cli"
      cmakeflags="${RVAL}"
   fi

   if [ ! -z "${OPTION_PHASE}" ]
   then
      r_uppercase "${OPTION_PHASE}"
      make::plugin::cmake::r_cmakeflags_add_flag "${cmakeflags}" "MULLE_MAKE_PHASE" "${RVAL}"
      cmakeflags="${RVAL}"
   fi

   #
   # For tcc can add some cmake values like CMAKE_C_COMPILER_WORKS=ON
   # but tcc doesn't work well on OSX because it can't link

   make::compiler::r_cmakeflags_values "${cc}" "${configuration}"
   if [ ! -z "${RVAL}" ]
   then
      local lines
      local line

      lines="${RVAL}"

      .foreachline line in ${lines}
      .do
         make::plugin::cmake::r_cmakeflags_add "${cmakeflags}" "${line}"
         cmakeflags="${RVAL}"
      .done
   fi

   local maketarget

   case "${cmd}" in
      build|project)
         maketarget=
      ;;

      install)
         [ -z "${dstdir}" ] && _internal_fail "dstdir is empty"
         maketarget="install"
      ;;

      *)
         maketarget="${cmd}"
      ;;
   esac

   dstdir="${dstdir}"
   if [ ! -z "${dstdir}" ]
   then
      make::plugin::cmake::r_convert_path_to_native "${dstdir}"
      make::plugin::cmake::r_cmakeflags_add_flag "${cmakeflags}" "CMAKE_INSTALL_PREFIX:PATH" "${RVAL}"
      cmakeflags="${RVAL}"
   fi

   local buildtype

   buildtype="${DEFINITION_CMAKE_BUILD_TYPE:-${configuration}}"
   if [ ! -z "${buildtype}" ]
   then
      make::plugin::cmake::r_cmakeflags_add_flag "${cmakeflags}" "CMAKE_BUILD_TYPE" "${buildtype}"
      cmakeflags="${RVAL}"
   fi

   if [ "${OPTION_MULLE_TEST}" = 'YES' ]
   then
      make::plugin::cmake::r_cmakeflags_add_flag "${cmakeflags}" "MULLE_TEST:BOOL" "ON"
      cmakeflags="${RVAL}"
   fi

   case "${DEFINITION_LIBRARY_STYLE}" in
      standalone)
         make::plugin::cmake::r_cmakeflags_add_flag "${cmakeflags}" "STANDALONE:BOOL" "ON"
         cmakeflags="${RVAL}"
      ;;

      static)
         make::plugin::cmake::r_cmakeflags_add_flag "${cmakeflags}" "BUILD_SHARED_LIBS:BOOL" "OFF"
         cmakeflags="${RVAL}"
      ;;

      dynamic)
         make::plugin::cmake::r_cmakeflags_add_flag "${cmakeflags}" "BUILD_SHARED_LIBS:BOOL" "ON"
         cmakeflags="${RVAL}"
      ;;
   esac

   make::plugin::cmake::r_cmakeflags_add_sdk_parameter "${cmakeflags}" "${sdk}"
   cmakeflags="${RVAL}"

   make::plugin::cmake::r_cmake_sdk_arguments "${cmakeflags}" "${sdk}" "${platform}"
   cmakeflags="${RVAL}"

   value="${DEFINITION_CMAKE_C_COMPILER:-${DEFINITION_CC}}"
   if [ ! -z "${value}" ]
   then
      # on windows mulle-clang-cl.exe will not be found. if it's not in the
      # PATH of windows (not wsl!)
#      case "${MULLE_UNAME}" in
#         windows)
#            value="`mudo which mulle-clang-cl.exe`" || exit 1
#            value="`wslpath -w "${value}" `"
#            value="${value//\\/\\\\}"
#         ;;
#      esac
      make::plugin::cmake::r_cmakeflags_add_flag "${cmakeflags}" "CMAKE_C_COMPILER" "${value}"
      cmakeflags="${RVAL}"
   fi

   if [ "${DEFINITION_PROJECT_LANGUAGE}" != "c" ]
   then
      value="${DEFINITION_CMAKE_CXX_COMPILER:-${DEFINITION_CXX}}"
      if [ ! -z "${value}" ]
      then
         make::plugin::cmake::r_cmakeflags_add_flag "${cmakeflags}" "CMAKE_CXX_COMPILER" "${value}"
         cmakeflags="${RVAL}"
      fi
   fi

   # this is now necessary, though undocumented apparently
   if [ ! -z "${DEFINITION_CMAKE_LINKER}" ]
   then
      make::plugin::cmake::r_cmakeflags_add_flag "${cmakeflags}" "CMAKE_LINKER:PATH" "${DEFINITION_CMAKE_LINKER}"
      cmakeflags="${RVAL}"
   fi

   local value

   #
   # for now only cflags and cxxflags are escaped, because otherwise
   # -DFOO="a string", doesn't work correctly. Not sure about the other flags
   # (didn't have problems)
   #
   value="${DEFINITION_CMAKE_C_FLAGS:-${cflags}}"
   if [ ! -z "${value}" ]
   then
      make::plugin::cmake::r_cmakeflags_add_toolflags "${cmakeflags}" "CMAKE_C_FLAGS" "${value}"
      cmakeflags="${RVAL}"
   fi

   value="${DEFINITION_CMAKE_CXX_FLAGS:-${cxxflags}}"
   if [ ! -z "${value}" ]
   then
      make::plugin::cmake::r_cmakeflags_add_toolflags "${cmakeflags}" "CMAKE_CXX_FLAGS" "${value}"
      cmakeflags="${RVAL}"
   fi

   if [ ! -z "${DEFINITION_CMAKE_SHARED_LINKER_FLAGS:-${ldflags}}" ]
   then
      value="${DEFINITION_CMAKE_SHARED_LINKER_FLAGS:-${ldflags}}"

      make::plugin::cmake::r_cmakeflags_add_toolflags "${cmakeflags}" "CMAKE_SHARED_LINKER_FLAGS" "${value}"
      cmakeflags="${RVAL}"
   fi

   if [ ! -z "${DEFINITION_CMAKE_EXE_LINKER_FLAGS:-${ldflags}}" ]
   then
      value="${DEFINITION_CMAKE_SHARED_LINKER_FLAGS:-${ldflags}}"

      make::plugin::cmake::r_cmakeflags_add_toolflags "${cmakeflags}" "CMAKE_EXE_LINKER_FLAGS" "${value}"
      cmakeflags="${RVAL}"
   fi

   #
   # CMAKE_INCLUDE_PATH doesn't really do what one expects it would
   # it's a setting for the rarely used find_file, but for mulle-c11 its
   # still useful apparently
   #
   local value

   value=${DEFINITION_CMAKE_INCLUDE_PATH:-${DEFINITION_INCLUDE_PATH}}
   if [ ! -z "${value}" ]
   then
      if [ -z "${DEFINITION_CMAKE_INCLUDE_PATH}" ] || make::definition::is_plus_key "CMAKE_INCLUDE_PATH"
      then
         value="${DEFINITION_INCLUDE_PATH//:/;}"
         make::plugin::cmake::r_convert_path_to_native "${value}"
         r_concat "${DEFINITION_CMAKE_INCLUDE_PATH}" "${RVAL}"
         value="${RVAL}"
      fi

      make::plugin::cmake::r_cmakeflags_add_flag "${cmakeflags}" "CMAKE_INCLUDE_PATH" "${value}"
      cmakeflags="${RVAL}"
   fi

   value=${DEFINITION_CMAKE_LIBRARY_PATH:-${DEFINITION_LIB_PATH}}
   if [ ! -z "${DEFINITION_CMAKE_LIBRARY_PATH:-${DEFINITION_LIB_PATH}}" ]
   then
      if [ -z "${DEFINITION_CMAKE_LIBRARY_PATH}"  ]
      then
         value="${DEFINITION_LIB_PATH//:/;}"
         make::plugin::cmake::r_convert_path_to_native "${value}"
         r_concat "${DEFINITION_CMAKE_LIBRARY_PATH}" "${RVAL}"
         value="${RVAL}"
      fi
      make::plugin::cmake::r_cmakeflags_add_flag "${cmakeflags}" "CMAKE_LIBRARY_PATH" "${value}"
      cmakeflags="${RVAL}"
   fi

   value=${DEFINITION_CMAKE_FRAMEWORK_PATH:-${DEFINITION_FRAMEWORKS_PATH}}
   if [ ! -z "${value}" ]
   then
      if [ -z "${DEFINITION_CMAKE_FRAMEWORK_PATH}" ] || make::definition::is_plus_key "CMAKE_FRAMEWORK_PATH"
      then
         value="${DEFINITION_FRAMEWORKS_PATH//:/;}"
         make::plugin::cmake::r_convert_path_to_native "${value}"
         r_concat "${DEFINITION_CMAKE_FRAMEWORK_PATH}" "${RVAL}"
         value="${RVAL}"
      fi

      make::plugin::cmake::r_cmakeflags_add_flag "${cmakeflags}" "CMAKE_FRAMEWORK_PATH" "${value}"
      cmakeflags="${RVAL}"
   fi

   #
   # the userdefined definitions must be quoted properly already
   #
   make::plugin::cmake::r_userdefined_definitions
   r_concat "${cmakeflags}" "${RVAL}"
   cmakeflags="${RVAL}"

   local makeflags
   local makefile
   local native_kitchendir

   make::plugin::cmake::r_convert_path_to_native "${absbuilddir}"
   native_kitchendir="${RVAL}"

   make::common::r_build_makefile "${MAKE}" "${native_kitchendir}"
   makefile="${RVAL}"

   make::common::r_build_make_flags "${MAKE}" "${DEFINITION_MAKEFLAGS}"
   makeflags="${RVAL}"

   local run

   #
   # phases need to rerun cmake
   #
   # Also, to flip/flop between serial and parallel phases, we should remember
   # this and then rerun cmake if we detect a change. We also want to blow
   # away the cache then.
   #
   run='YES'

   if [ "${MULLE_FLAG_MAGNUM_FORCE}" = 'YES' -o "${OPTION_PHASE}" = 'Headers' ]
   then
      remove_file_if_present "${kitchendir}/CMakeCache.txt"
   else
      #
      # for singlephase only, figure out, if we can skip rerunning cmake,
      #
      if [ -z "${OPTION_PHASE}" ]
      then
         local oldphase

         oldphase="`rexekutor egrep -v '^#' "${kitchendir}/.phase" 2> /dev/null `"
         if [ -z "${oldphase}" ]
         then
            run="${OPTION_RERUN_CMAKE:-DEFAULT}"
         else
            # if there was a previous phase the cache makes us fail
            # with can not install or so...
            remove_file_if_present "${kitchendir}/CMakeCache.txt"
         fi

         if [ "${run}" = 'DEFAULT' ]
         then
            if ! make::plugin::cmake::cmake_files_are_newer_than_makefile "${absprojectdir}" "${makefile}"
            then
               run='NO'
               _log_fluff "cmake skipped, as no changes to cmake files have been \
found in \"${absprojectdir#${MULLE_USER_PWD}/}\""
            else
               run='YES'
            fi
         fi
      fi
   fi

   if [ -z "${OPTION_PHASE}" ]
   then
      remove_file_if_present "${kitchendir}/.phase"
   else
      redirect_exekutor "${kitchendir}/.phase" printf "%s\n" "${OPTION_PHASE}"
   fi

   local env_common

   make::build::r_env_flags
   env_common="${RVAL}"

   local logname2

   r_extensionless_basename "${MAKE}"
   logname2="${RVAL}"

   local logfile1
   local logfile2

   mkdir_if_missing "${logsdir}"

   make::common::r_build_log_name "${logsdir}" "cmake"
   logfile1="${RVAL}"

   make::common::r_build_log_name "${logsdir}" "${logname2}"
   logfile2="${RVAL}"

   local teefile1
   local teefile2
   local grepper
   local greplog

   teefile1="/dev/null"
   teefile2="/dev/null"
   grepper="make::common::log_grep_warning_error"
   greplog='YES'

   if [ "$MULLE_FLAG_EXEKUTOR_DRY_RUN" = 'YES' ]
   then
      logfile1="/dev/null"
      logfile2="/dev/null"
   else
      _log_verbose "Build logs will be in \"${logfile1#${MULLE_USER_PWD}/}\" \
and \"${logfile2#${MULLE_USER_PWD}/}\""
   fi

   if [ "$MULLE_FLAG_LOG_VERBOSE" = 'YES' ]
   then
      make::common::r_safe_tty
      teefile1="${RVAL}"
      teefile2="${teefile1}"
      grepper="make::common::log_delete_all"
      greplog='NO'
   fi

   (
      exekutor cd "${kitchendir}" || fail "failed to enter ${kitchendir}"

      PATH="${DEFINITION_PATH:-${PATH}}"
      log_fluff "PATH temporarily set to $PATH"

      if [ "${MULLE_FLAG_LOG_ENVIRONMENT}" = 'YES' ]
      then
         env | sort >&2
      fi

      if [ "${run}" = 'YES' ]
      then
         if ! logging_tee_eval_exekutor "${logfile1}" "${teefile1}" \
                  "${env_common}" \
                  "'${CMAKE}'" -G "'${CMAKE_GENERATOR}'" \
                               "${CMAKEFLAGS}" \
                               "${cmakeflags}" \
                               "'${projectdir}'" | ${grepper}
         then
            make::common::build_fail "${logfile1}" "cmake" "${PIPESTATUS[ 0]}" "${greplog}"
         fi

         #
         # This is for OPTION_PHASE=Headers, if there are no headers to install
         # cmake doesn't create an entry for "install" in the ninja build
         # file and ninja freaks out.
         #
         if [ "${OPTION_PHASE}" = 'Headers' -a "${maketarget}" = 'install' ]
         then
            if [ -e "build.ninja" -a -e "cmake_install.cmake" ]
            then
               if ! rexekutor egrep -q ' *cmake_install.cmake$' "build.ninja"
               then
                  log_verbose "No headers to install. Skipping ${MAKE}"
                  return 0
               fi
            fi
         fi
      fi

      if ! logging_tee_eval_exekutor "${logfile2}" "${teefile2}" \
               "${env_common}" \
               "'${MAKE}'" "${MAKEFLAGS}" "${makeflags}" "${maketarget}" | ${grepper}
      then
         make::common::build_fail "${logfile2}" "make" "${PIPESTATUS[ 0]}" "${greplog}"
      fi
   ) || exit 1
}


make::plugin::cmake::r_test()
{
   log_entry "make::plugin::cmake::r_test" "$@"

   [ $# -eq 1 ] || _internal_fail "api error"

   local srcdir="$1"

   local projectfile
   local projectdir

   RVAL=""

   if ! make::common::r_find_nearest_matching_pattern "${srcdir}" "CMakeLists.txt"
   then
      log_fluff "There is no CMakeLists.txt file in \"${srcdir}\""
      return 1
   fi
   projectfile="${RVAL}"

   case "${MULLE_UNAME}" in
      mingw*)
         include "platform::mingw"
         platform::mingw::setup_buildenvironment
      ;;
   esac

   make::plugin::cmake::tools_environment

   if [ -z "${CMAKE}" ]
   then
      log_warning "Found a CMakeLists.txt, but ${C_RESET}${C_BOLD}cmake${C_WARNING} is not installed"
      return 1
   fi

   if [ -z "${MAKE}" ]
   then
      fail "No make available"
   fi

   log_verbose "Found cmake project \"${projectfile#${MULLE_USER_PWD}/}\""

   RVAL="${projectfile}"

   return 0
}


make::plugin::cmake::initialize()
{
   log_entry "make::plugin::cmake::initialize"

   if [ -z "${MULLE_STRING_SH}" ]
   then
      . "${MULLE_BASHFUNCTIONS_LIBEXEC_DIR}/mulle-string.sh" || return 1
   fi
   if [ -z "${MULLE_PATH_SH}" ]
   then
      . "${MULLE_BASHFUNCTIONS_LIBEXEC_DIR}/mulle-path.sh" || return 1
   fi
   if [ -z "${MULLE_FILE_SH}" ]
   then
      . "${MULLE_BASHFUNCTIONS_LIBEXEC_DIR}/mulle-file.sh" || return 1
   fi
}

make::plugin::cmake::initialize

:

