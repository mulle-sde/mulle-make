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


r_platform_cmake_generator()
{
   log_entry "r_platform_cmake_generator" "$@"

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


r_find_cmake()
{
   log_entry "r_find_cmake" "$@"

   local toolname
   local tooldefaultname

   tooldefaultname="cmake${MULLE_EXE_EXTENSION}"
   toolname="${OPTION_CMAKE:-${CMAKE:-${tooldefaultname}}}"
   r_verify_binary "${toolname}" "cmake" "${tooldefaultname}"
}


tools_environment_cmake()
{
   log_entry "tools_environment_cmake" "$@"

   tools_environment_common

   local defaultgenerator

   r_find_cmake
   CMAKE="${RVAL}"

   r_make_for_plugin "cmake" ""
   MAKE="${RVAL}"

   r_platform_cmake_generator "${MAKE}"
   defaultgenerator="${RVAL}"

   CMAKE_GENERATOR="${OPTION_CMAKE_GENERATOR:-${defaultgenerator}}"

}


r_cmakeflags_add_sdk_parameter()
{
   log_entry "r_cmakeflags_add_sdk_parameter" "$@"

   local cmakeflags="$1"
   local sdk="$2"

   if [ "${OPTION_DETERMINE_SDK}" = 'NO' ]
   then
      return
   fi

   case "${MULLE_UNAME}" in
      "darwin")
         r_compiler_get_sdkpath "${sdk}"
         if [ ! -z "${RVAL}" ]
         then
            r_cmakeflags_add_flag "${cmakeflags}" "CMAKE_OSX_SYSROOT" "${RVAL}"
            return 0
         fi
      ;;
   esac

   RVAL="${cmakeflags}"
}


#
# this should be a plugin based solution
# for now hardcode it
#
r_cmake_sdk_arguments()
{
   log_entry "r_cmake_sdk_arguments" "$@"

   local cmakeflags="$1"
   local sdk="$2"
   local platform="$3"

   case "${sdk}" in
      macos*)
      ;;

      # stuff won't compile unless ARCHS is specified for iphoneos
      # architectures are somewhat dependent on SDK and baselines
      # its complicated:
      # See: https://github.com/leetal/ios-cmake/blob/master/ios.toolchain.cmake
      #
      iphoneos*)
         r_cmakeflags_add_flag "${cmakeflags}" "CMAKE_OSX_ARCHITECTURES" "armv7;armv7s;arm64;arm64e"
         cmakeflags="${RVAL}"
      ;;

      iphonesimulator*)
         r_cmakeflags_add_flag "${cmakeflags}" "CMAKE_OSX_ARCHITECTURES" "x86_64"
         cmakeflags="${RVAL}"
      ;;

      android*)
         r_cmakeflags_add_flag "${cmakeflags}" "CMAKE_TOOLCHAIN_FILE" "\${ANDROID_NDK}/build/cmake/android.toolchain.cmake"
         cmakeflags="${RVAL}"
      ;;
   esac
}


cmake_files_are_newer_than_makefile()
{
   log_entry "cmake_files_are_newer_than_makefile" "$@"

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


debug_cmake()
{
   echo ">>>" >&2
   for i in "$@"
   do
     printf "%s\n" "$i"  >&2
   done
   echo "<<<"  >&2
}


r_cmakeflags_add_flag()
{
   local cmakeflags="$1"
   local flag="$2"
   local value="$3"

   r_escaped_singlequotes "${value}"
   r_escaped_shell_string "-D${flag}=${RVAL}"
   r_concat "${cmakeflags}" "${RVAL}"
}


r_cmakeflags_add()
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


r_cmakeflags_add_toolflags()
{
   log_entry "r_cmakeflags_add_toolflags" "$@"

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
r_cmake_userdefined_definitions()
{
   log_entry "r_cmake_userdefined_definitions" "$@"

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
   keys=`all_userdefined_unknown_keys`

   local key
   local value
   local cmakeflags

   IFS=$'\n'
   for key in ${keys}
   do
      IFS="${DEFAULT_IFS}"

      value="${!key}"
      r_escaped_shell_string "${value}"
      r_cmakeflags_add_flag "${cmakeflags}" "${key#OPTION_}" "${value}"
      cmakeflags="${RVAL}"
   done
   IFS="${DEFAULT_IFS}"

   RVAL="${cmakeflags}"

   log_debug "User definition: ${RVAL}"
}


#
# If we pass command line parameters to cmake or ninja,
# we are compiling for a windows filesystem. Those tools
# can't deal with /mnt/d, but expect d:
#
r_convert_path_to_native()
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
build_cmake()
{
   log_entry "build_cmake" "$@"

   [ $# -ge 9 ] || internal_fail "api error"

   local cmd="$1"; shift
   local projectfile="$1"; shift
   local sdk="$1"; shift
   local platform="$1"; shift
   local configuration="$1"; shift
   local srcdir="$1"; shift
   local dstdir="$1"; shift
   local kitchendir="$1"; shift
   local logsdir="$1"; shift

   [ -z "${cmd}" ] && internal_fail "cmd is empty"
   [ -z "${projectfile}" ] && internal_fail "projectfile is empty"
   [ -z "${configuration}" ] && internal_fail "configuration is empty"
   [ -z "${platform}" ] && internal_fail "platform is empty"
   [ -z "${srcdir}" ] && internal_fail "srcdir is empty"
   [ -z "${kitchendir}" ] && internal_fail "kitchendir is empty"
   [ -z "${logsdir}" ] && internal_fail "logsdir is empty"
   [ -z "${sdk}" ] && internal_fail "sdk is empty"

   # CMAKE=debug_cmake

   # need this now
   mkdir_if_missing "${kitchendir}"

   local cflags
   local cxxflags
   local cppflags
   local ldflags

   r_compiler_cflags_value "${OPTION_CC}" "${configuration}" 'NO'
   cflags="${RVAL}"

   case "${OPTION_PROJECT_LANGUAGE}" in
      [cC]|[oO][bB][jJ]*[cC])
         r_compiler_cxxflags_value "${OPTION_CXX:-${OPTION_CC}}" "${configuration}" 'NO'
         cxxflags="${RVAL}"
      ;;
   esac

   r_compiler_cppflags_value "${OPTION_CC}" "${configuration}"
   cppflags="${RVAL}"
   r_compiler_ldflags_value "${OPTION_CC}" "${configuration}"
   ldflags="${RVAL}"

   # this produces quoted output for
   #  cflags
   #  cppflags
   #  cxxflags
   #  ldflags
   #


   # __add_sdk_path_tool_flags # will be done below
   __add_header_and_library_path_tool_flags

   r_sdk_cflags "${sdk}" "${platform}"
   r_concat "${cflags}" "${RVAL}"

   if [ ! -z "${cppflags}" ]
   then
      r_concat "${cflags}" "${cppflags}"
      cflags="${RVAL}"

      if [ "${OPTION_PROJECT_LANGUAGE}" != "c" ]
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
         r_projectdir_relative_to_builddir "${absbuilddir}" "${absprojectdir}"
         projectdir="${RVAL}"
      ;;
   esac

   if [ "${MULLE_FLAG_LOG_SETTINGS}" = 'YES' ]
   then
      log_trace2 "cflags:        ${cflags}"
      log_trace2 "cppflags:      ${cppflags}"
      log_trace2 "cxxflags:      ${cxxflags}"
      log_trace2 "ldflags:       ${ldflags}"
      log_trace2 "projectfile:   ${projectfile}"
      log_trace2 "projectdir:    ${projectdir}"
      log_trace2 "absprojectdir: ${absprojectdir}"
      log_trace2 "absbuilddir:   ${absbuilddir}"
      log_trace2 "projectdir:    ${projectdir}"
   fi

   local cmakeflags

   cmakeflags="${OPTION_CMAKEFLAGS}"

   if [ "${MULLE_FLAG_LOG_SETTINGS}" = 'YES' ]
   then
      log_trace2 "PREFIX:        ${OPTION_PREFIX}"
      log_trace2 "CMAKEFLAGS:    ${OPTION_CMAKEFLAGS}"
   fi

   #
   # this should export a compile_commands.json command, which
   # by default should be helpful
   #
   if [ "${OPTION_CMAKE_COMPILE_COMMANDS}" != 'NO' ]
   then
      r_cmakeflags_add_flag "${cmakeflags}" "CMAKE_EXPORT_COMPILE_COMMANDS" "ON"
      cmakeflags="${RVAL}"
   fi

   if [ "${MULLE_FLAG_LOG_VERBOSE}" != 'YES' ]
   then
      r_cmakeflags_add "${cmakeflags}" "--no-warn-unused-cli"
      cmakeflags="${RVAL}"
   fi

   if [ ! -z "${OPTION_PHASE}" ]
   then
      local phase

      phase="`tr 'a-z' 'A-Z' <<< "${OPTION_PHASE}"`"
      r_cmakeflags_add_flag "${cmakeflags}" "MULLE_MAKE_PHASE" "${phase}"
      cmakeflags="${RVAL}"
   fi

   local maketarget

   case "${cmd}" in
      build|project)
         maketarget=
         if [ ! -z "${OPTION_PREFIX}" ]
         then
            r_convert_path_to_native "${OPTION_PREFIX}"
            r_cmakeflags_add_flag "${cmakeflags}" "CMAKE_INSTALL_PREFIX:PATH" "${RVAL}"
            cmakeflags="${RVAL}"
         fi
      ;;

      install)
         [ -z "${dstdir}" ] && internal_fail "srcdir is empty"
         maketarget="install"
         if [ ! -z "${OPTION_PREFIX}" ]
         then
            r_convert_path_to_native "${OPTION_PREFIX}"
            r_cmakeflags_add_flag "${cmakeflags}" "CMAKE_INSTALL_PREFIX:PATH" "${RVAL}"
            cmakeflags="${RVAL}"
         else
            r_convert_path_to_native "${dstdir}"
            r_cmakeflags_add_flag "${cmakeflags}" "CMAKE_INSTALL_PREFIX:PATH" "${RVAL}"
            cmakeflags="${RVAL}"
         fi
      ;;

      *)
         maketarget="${cmd}"
         if [ ! -z "${OPTION_PREFIX}" ]
         then
            r_convert_path_to_native "${OPTION_PREFIX}"
            r_cmakeflags_add_flag "${cmakeflags}" "CMAKE_INSTALL_PREFIX:PATH" "${RVAL}"
            cmakeflags="${RVAL}"
         fi
      ;;
   esac

   local buildtype

   buildtype="${OPTION_CMAKE_BUILD_TYPE:-${configuration}}"
   if [ ! -z "${buildtype}" ]
   then
      r_cmakeflags_add_flag "${cmakeflags}" "CMAKE_BUILD_TYPE" "${buildtype}"
      cmakeflags="${RVAL}"
   fi

   if [ "${OPTION_MULLE_TEST}" = 'YES' ]
   then
      r_cmakeflags_add_flag "${cmakeflags}" "MULLE_TEST:BOOL" "ON"
      cmakeflags="${RVAL}"
   fi

   case "${OPTION_LIBRARY_STYLE}" in
      standalone)
         r_cmakeflags_add_flag "${cmakeflags}" "STANDALONE:BOOL" "ON"
         cmakeflags="${RVAL}"
      ;;

      static)
         r_cmakeflags_add_flag "${cmakeflags}" "BUILD_SHARED_LIBS:BOOL" "OFF"
         cmakeflags="${RVAL}"
      ;;

      dynamic)
         r_cmakeflags_add_flag "${cmakeflags}" "BUILD_SHARED_LIBS:BOOL" "ON"
         cmakeflags="${RVAL}"
      ;;
   esac

   r_cmakeflags_add_sdk_parameter "${cmakeflags}" "${sdk}"
   cmakeflags="${RVAL}"

   r_cmake_sdk_arguments "${cmakeflags}" "${sdk}" "${platform}"
   cmakeflags="${RVAL}"

   if [ ! -z "${OPTION_CMAKE_C_COMPILER:-${OPTION_CC}}" ]
   then
      r_cmakeflags_add_flag "${cmakeflags}" "CMAKE_C_COMPILER" "${OPTION_CMAKE_C_COMPILER:-${OPTION_CC}}"
      cmakeflags="${RVAL}"
   fi

   if [ "${OPTION_PROJECT_LANGUAGE}" != "c" ]
   then
      if [ ! -z "${OPTION_CMAKE_CXX_COMPILER:-${OPTION_CXX}}" ]
      then
         r_cmakeflags_add_flag "${cmakeflags}" "CMAKE_CXX_COMPILER" "${OPTION_CMAKE_CXX_COMPILER:-${OPTION_CXX}}"
         cmakeflags="${RVAL}"
      fi
   fi

   # this is now necessary, though undocumented apparently
   if [ ! -z "${OPTION_CMAKE_LINKER:-${LD}}" ]
   then
      r_cmakeflags_add_flag "${cmakeflags}" "CMAKE_LINKER:PATH" "${LD}"
      cmakeflags="${RVAL}"
   fi

   local escaped
   local value

   #
   # for now only cflags and cxxflags are escaped, because otherwise
   # -DFOO="a string", doesn't work correctly. Not sure about the other flags
   # (didn't have problems)
   #
   value="${OPTION_CMAKE_C_FLAGS:-${cflags}}"
   if [ ! -z "${value}" ]
   then
      r_cmakeflags_add_toolflags "${cmakeflags}" "CMAKE_C_FLAGS" "${value}"
      cmakeflags="${RVAL}"
   fi

   value="${OPTION_CMAKE_CXX_FLAGS:-${cxxflags}}"
   if [ ! -z "${value}" ]
   then
      r_cmakeflags_add_toolflags "${cmakeflags}" "CMAKE_CXX_FLAGS" "${value}"
      cmakeflags="${RVAL}"
   fi

   if [ ! -z "${OPTION_CMAKE_SHARED_LINKER_FLAGS:-${ldflags}}" ]
   then
      value="${OPTION_CMAKE_SHARED_LINKER_FLAGS:-${ldflags}}"

      r_cmakeflags_add_toolflags "${cmakeflags}" "CMAKE_SHARED_LINKER_FLAGS" "${value}"
      cmakeflags="${RVAL}"
   fi

   if [ ! -z "${OPTION_CMAKE_EXE_LINKER_FLAGS:-${ldflags}}" ]
   then
      value="${OPTION_CMAKE_SHARED_LINKER_FLAGS:-${ldflags}}"

      r_cmakeflags_add_toolflags "${cmakeflags}" "CMAKE_EXE_LINKER_FLAGS" "${value}"
      cmakeflags="${RVAL}"
   fi

   #
   # CMAKE_INCLUDE_PATH doesn't really do what one expects it would
   # it's a setting for the rarely used find_file, but for mulle-c11 its
   # still useful apparently
   #
   local value

   value=${OPTION_CMAKE_INCLUDE_PATH:-${OPTION_INCLUDE_PATH}}
   if [ ! -z "${value}" ]
   then
      if [ -z "${OPTION_CMAKE_INCLUDE_PATH}" ] || is_plus_key "CMAKE_INCLUDE_PATH"
      then
         value="${OPTION_INCLUDE_PATH//:/;}"
         r_convert_path_to_native "${value}"
         r_concat "${OPTION_CMAKE_INCLUDE_PATH}" "${RVAL}"
         value="${RVAL}"
      fi

      r_cmakeflags_add_flag "${cmakeflags}" "CMAKE_INCLUDE_PATH" "${value}"
      cmakeflags="${RVAL}"
   fi

   value=${OPTION_CMAKE_LIBRARY_PATH:-${OPTION_LIB_PATH}}
   if [ ! -z "${OPTION_CMAKE_LIBRARY_PATH:-${OPTION_LIB_PATH}}" ]
   then
      if [ -z "${OPTION_CMAKE_LIBRARY_PATH}"  ]
      then
         value="${OPTION_LIB_PATH//:/;}"
         r_convert_path_to_native "${value}"
         r_concat "${OPTION_CMAKE_LIBRARY_PATH}" "${RVAL}"
         value="${RVAL}"
      fi
      r_cmakeflags_add_flag "${cmakeflags}" "CMAKE_LIBRARY_PATH" "${value}"
      cmakeflags="${RVAL}"
   fi

   value=${OPTION_CMAKE_FRAMEWORK_PATH:-${OPTION_FRAMEWORKS_PATH}}
   if [ ! -z "${value}" ]
   then
      if [ -z "${OPTION_CMAKE_FRAMEWORK_PATH}" ] || is_plus_key "CMAKE_FRAMEWORK_PATH"
      then
         value="${OPTION_FRAMEWORKS_PATH//:/;}"
         r_convert_path_to_native "${value}"
         r_concat "${OPTION_CMAKE_FRAMEWORK_PATH}" "${RVAL}"
         value="${RVAL}"
      fi

      r_cmakeflags_add_flag "${cmakeflags}" "CMAKE_FRAMEWORK_PATH" "${value}"
      cmakeflags="${RVAL}"
   fi

   #
   # the userdefined definitions must be quoted properly already
   #
   r_cmake_userdefined_definitions
   r_concat "${cmakeflags}" "${RVAL}"
   cmakeflags="${RVAL}"

   local makeflags

   r_convert_path_to_native "${kitchendir}"
   r_build_make_flags "${MAKE}" "${OPTION_MAKEFLAGS}" "${RVAL}"
   makeflags="${RVAL}"

   local run_cmake

   run_cmake='YES'

   # phases need to rerun cmake
   if [ -z "${OPTION_PHASE}" ]
   then
      if ! cmake_files_are_newer_than_makefile "${absprojectdir}" "${makefile}"
      then
         run_cmake='NO'
         log_fluff "Cmake run skipped as no changes to cmake files have been \
found in \"${absprojectdir}\""
      fi
   fi

   local env_common

   r_mulle_make_env_flags
   env_common="${RVAL}"

   local logname2

   r_extensionless_basename "${MAKE}"
   logname2="${RVAL}"

   local logfile1
   local logfile2

   mkdir_if_missing "${logsdir}"

   r_build_log_name "${logsdir}" "cmake"
   logfile1="${RVAL}"

   r_build_log_name "${logsdir}" "${logname2}"
   logfile2="${RVAL}"

   local teefile1
   local teefile2
   local grepper

   teefile1="/dev/null"
   teefile2="/dev/null"
   grepper="log_grep_warning_error"

   if [ "$MULLE_FLAG_EXEKUTOR_DRY_RUN" = 'YES' ]
   then
      logfile1="/dev/null"
      logfile2="/dev/null"
   else
      log_verbose "Build logs will be in \"${logfile1#${MULLE_USER_PWD}/}\" and \"${logfile2#${MULLE_USER_PWD}/}\""
   fi

   if [ "$MULLE_FLAG_LOG_VERBOSE" = 'YES' ]
   then
      r_safe_tty
      teefile1="${RVAL}"
      teefile2="${teefile1}"
      grepper="log_delete_all"
   fi

   (
      exekutor cd "${kitchendir}" || fail "failed to enter ${kitchendir}"

      PATH="${OPTION_PATH:-${PATH}}"
      log_fluff "PATH temporarily set to $PATH"

      if [ "${MULLE_FLAG_LOG_ENVIRONMENT}" = 'YES' ]
      then
         env | sort >&2
      fi

      set -o pipefail # should be set already
      if [ "${run_cmake}" = 'YES' ]
      then
         if ! logging_tee_eval_exekutor "${logfile1}" "${teefile1}" \
                  "${env_common}" \
                  "'${CMAKE}'" -G "'${CMAKE_GENERATOR}'" \
                               "${CMAKEFLAGS}" \
                               "${cmakeflags}" \
                               "'${projectdir}'" | ${grepper}
         then
            build_fail "${logfile1}" "cmake" "${PIPESTATUS[ 0]}"
         fi
      fi
      if ! logging_tee_eval_exekutor "${logfile2}" "${teefile2}" \
               "${env_common}" \
               "'${MAKE}'" "${MAKEFLAGS}" "${makeflags}" "${maketarget}"  | ${grepper}
      then
         build_fail "${logfile2}" "make" "${PIPESTATUS[ 0]}"
      fi
   ) || exit 1
}


r_test_cmake()
{
   log_entry "r_test_cmake" "$@"

   [ $# -eq 1 ] || internal_fail "api error"

   local srcdir="$1"

   local projectfile
   local projectdir

   RVAL=""

   if ! r_find_nearest_matching_pattern "${srcdir}" "CMakeLists.txt"
   then
      log_fluff "There is no CMakeLists.txt file in \"${srcdir}\""
      return 1
   fi
   projectfile="${RVAL}"

   case "${MULLE_UNAME}" in
      mingw*)
         if [ -z "${MULLE_MAKE_MINGW_SH}" ]
         then
            . "${MULLE_MAKE_LIBEXEC_DIR}/mulle-make-mingw.sh" || exit 1
         fi
         setup_mingw_buildenvironment
      ;;
   esac

   tools_environment_cmake

   if [ -z "${CMAKE}" ]
   then
      log_warning "Found a CMakeLists.txt, but ${C_RESET}${C_BOLD}cmake${C_WARNING} is not installed"
      return 1
   fi

   if [ -z "${MAKE}" ]
   then
      fail "No make available"
   fi

   log_fluff "Found cmake project file \"${projectfile}\""

   RVAL="${projectfile}"

   return 0
}


cmake_plugin_initialize()
{
   log_entry "cmake_plugin_initialize"

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

cmake_plugin_initialize

:

