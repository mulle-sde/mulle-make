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
   local makepath="$1"

   local name

   r_fast_basename "${makepath}"
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
}


r_find_cmake()
{
   local toolname

   toolname="${OPTION_CMAKE:-${CMAKE:-cmake}}"
   r_verify_binary "${toolname}" "cmake" "cmake"
}


tools_environment_cmake()
{
   tools_environment_make "" "cmake"

   local defaultgenerator
   local RVAL

   r_platform_cmake_generator "${MAKE}"
   defaultgenerator="${RVAL}"

   r_find_cmake

   CMAKE="${RVAL}"
   CMAKE_GENERATOR="${OPTION_CMAKE_GENERATOR:-${defaultgenerator}}"
}


r_cmake_sdk_parameter()
{
   local sdk="$1"

   RVAL=""
   case "${MULLE_UNAME}" in
      "darwin")
         r_compiler_sdk_parameter "${sdk}"
         if [ ! -z "${RVAL}" ]
         then
            log_fluff "Set cmake -DCMAKE_OSX_SYSROOT to \"${RVAL}\""
            RVAL="-DCMAKE_OSX_SYSROOT='${RVAL}'"
         fi
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

   IFS=":"
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


#
# remove old builddir, create a new one
# depending on configuration cmake with flags
# build stuff into dependencies
# TODO: cache commandline in a file $ and emit instead of rebuilding it every time
#
build_cmake()
{
   log_entry "build_cmake" "$@"

   [ $# -eq 8 ] || internal_fail "api error"

   local cmd="$1"; shift
   local projectfile="$1"; shift
   local configuration="$1"; shift
   local srcdir="$1"; shift
   local dstdir="$1"; shift
   local builddir="$1"; shift
   local logsdir="$1"; shift
   local sdk="$1"; shift

   [ -z "${cmd}" ] && internal_fail "cmd is empty"
   [ -z "${projectfile}" ] && internal_fail "projectfile is empty"
   [ -z "${configuration}" ] && internal_fail "configuration is empty"
   [ -z "${srcdir}" ] && internal_fail "srcdir is empty"
   [ -z "${builddir}" ] && internal_fail "builddir is empty"
   [ -z "${logsdir}" ] && internal_fail "logsdir is empty"
   [ -z "${sdk}" ] && internal_fail "sdk is empty"

   # need this now
   mkdir_if_missing "${builddir}"

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

   r_compiler_cppflags_value
   cppflags="${RVAL}"
   r_compiler_ldflags_value
   ldflags="${RVAL}"

   __add_path_tool_flags

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

   r_fast_dirname "${projectfile}"
   projectdir="${RVAL}"
   r_simplified_absolutepath "${projectdir}"
   absprojectdir="${RVAL}"
   r_simplified_absolutepath "${builddir}"
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

   local cmake_flags

   cmake_flags="${OPTION_CMAKEFLAGS}"

   if [ ! -z "${OPTION_PHASE}" ]
   then
      local phase

      phase="`tr 'a-z' 'A-Z' <<< "${OPTION_PHASE}"`"
      r_concat "${cmake_flags}" "-DMULLE_MAKE_PHASE='${phase}'"
      cmake_flags="${RVAL}"
   fi

   local maketarget

   case "${cmd}" in
      build|project)
         maketarget=
         if [ ! -z "${OPTION_PREFIX}" ]
         then
            r_concat "${cmake_flags}" "-DCMAKE_INSTALL_PREFIX:PATH='${OPTION_PREFIX}'"
            cmake_flags="${RVAL}"
         fi
      ;;

      install)
         [ -z "${dstdir}" ] && internal_fail "srcdir is empty"
         maketarget="install"
         if [ ! -z "${OPTION_PREFIX}" ]
         then
            r_concat "${cmake_flags}" "-DCMAKE_INSTALL_PREFIX:PATH='${OPTION_PREFIX}'"
            cmake_flags="${RVAL}"
         else
            r_concat "${cmake_flags}" "-DCMAKE_INSTALL_PREFIX:PATH='${dstdir}'"
            cmake_flags="${RVAL}"
         fi
      ;;
   esac

   if [ ! -z "${OPTION_CMAKE_BUILD_TYPE:-${configuration}}" ]
   then
      r_concat "${cmake_flags}" "-DCMAKE_BUILD_TYPE='${OPTION_CMAKE_BUILD_TYPE:-${configuration}}'"
      cmake_flags="${RVAL}"
   fi

   if [ "${MULLE_FLAG_LOG_SETTINGS}" = 'YES' ]
   then
      log_trace2 "PREFIX:        ${OPTION_PREFIX}"
      log_trace2 "CMAKEFLAGS:    ${OPTION_CMAKEFLAGS}"
   fi

   local sdkparameter

   r_cmake_sdk_parameter "${sdk}"
   sdkparameter="${RVAL}"

   if [ -z "${sdkparameter}" ]
   then
      r_concat "${cmake_flags}" "${sdkparameter}"
      cmake_flags="${RVAL}"
   fi

   if [ ! -z "${OPTION_CMAKE_C_COMPILER:-${OPTION_CC}}" ]
   then
      r_concat "${cmake_flags}" "-DCMAKE_C_COMPILER='${OPTION_CMAKE_C_COMPILER:-${OPTION_CC}}'"
      cmake_flags="${RVAL}"
   fi

   if [ "${OPTION_PROJECT_LANGUAGE}" != "c" ]
   then
      if [ ! -z "${OPTION_CMAKE_CXX_COMPILER:-${OPTION_CXX}}" ]
      then
         r_concat "${cmake_flags}" "-DCMAKE_CXX_COMPILER='${OPTION_CMAKE_CXX_COMPILER:-${OPTION_CXX}}'"
         cmake_flags="${RVAL}"
      fi
   fi

   # this is now necessary, though undocumented apparently
   if [ ! -z "${OPTION_CMAKE_LINKER:-${LD}}" ]
   then
      r_concat "${cmake_flags}" "-DCMAKE_LINKER:PATH='${LD}'"
      cmake_flags="${RVAL}"
   fi

   if [ ! -z "${OPTION_CMAKE_C_FLAGS:-${cflags}}" ]
   then
      r_concat "${cmake_flags}" "-DCMAKE_C_FLAGS='${OPTION_CMAKE_C_FLAGS:-${cflags}}'"
      cmake_flags="${RVAL}"
   fi

   if [ ! -z "${OPTION_CMAKE_CXX_FLAGS:-${cxxflags}}" ]
   then
      r_concat "${cmake_flags}" "-DCMAKE_CXX_FLAGS='${OPTION_CMAKE_CXX_FLAGS:-${cxxflags}}'"
      cmake_flags="${RVAL}"
   fi

   if [ ! -z "${OPTION_CMAKE_SHARED_LINKER_FLAGS:-${ldflags}}" ]
   then
      r_concat "${cmake_flags}" "-DCMAKE_SHARED_LINKER_FLAGS='${OPTION_CMAKE_SHARED_LINKER_FLAGS:-${ldflags}}'"
      cmake_flags="${RVAL}"
   fi

   if [ ! -z "${OPTION_CMAKE_EXE_LINKER_FLAGS:-${ldflags}}" ]
   then
      r_concat "${cmake_flags}" "-DCMAKE_EXE_LINKER_FLAGS='${OPTION_CMAKE_EXE_LINKER_FLAGS:-${ldflags}}'"
      cmake_flags="${RVAL}"
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
         value="$(tr ':' ';' <<< "${OPTION_INCLUDE_PATH}")"
         r_concat "${OPTION_CMAKE_INCLUDE_PATH}" "${value}"
         value="${RVAL}"
      fi
      r_concat "${cmake_flags}" "-DCMAKE_INCLUDE_PATH='${value}'"
      cmake_flags="${RVAL}"
   fi

   value=${OPTION_CMAKE_LIBRARY_PATH:-${OPTION_LIB_PATH}}
   if [ ! -z "${OPTION_CMAKE_LIBRARY_PATH:-${OPTION_LIB_PATH}}" ]
   then
      if [ -z "${OPTION_CMAKE_LIBRARY_PATH}"  ]
      then
         value="$(tr ':' ';' <<< "${OPTION_LIB_PATH}")"
         r_concat "${OPTION_CMAKE_LIBRARY_PATH}" "${value}"
         value="${RVAL}"
      fi
      r_concat "${cmake_flags}" "-DCMAKE_LIBRARY_PATH='${value}'"
      cmake_flags="${RVAL}"
   fi

   value=${OPTION_CMAKE_FRAMEWORK_PATH:-${OPTION_FRAMEWORKS_PATH}}
   if [ ! -z "${value}" ]
   then
      if [ -z "${OPTION_CMAKE_FRAMEWORK_PATH}" ] || is_plus_key "CMAKE_FRAMEWORK_PATH"
      then
         value="$(tr ':' ';' <<< "${OPTION_FRAMEWORKS_PATH}")"
         r_concat "${OPTION_CMAKE_FRAMEWORK_PATH}" "${value}"
         value="${RVAL}"
      fi
      r_concat "${cmake_flags}" "-DCMAKE_FRAMEWORK_PATH='${value}'"
      cmake_flags="${RVAL}"
   fi

   local other_buildsettings

   other_buildsettings="`emit_userdefined_definitions "-D" "=" "=" ""`"
   if [ ! -z "${other_buildsettings}" ]
   then
      r_concat "${cmake_flags}" "${other_buildsettings}"
      cmake_flags="${RVAL}"
   fi

   local make_flags

   make_flags="${OPTION_MAKEFLAGS}"

   #
   # hackish
   # figure out if we need to run cmake, by looking for cmakefiles and
   # checking if they are newer than the MAKEFILE
   #
   case "${MAKE}" in
      *ninja)
         makefile="${builddir}/build.ninja"
         if [ "${MULLE_FLAG_LOG_VERBOSE}" = 'YES' ]
         then
            r_concat "${make_flags}" "-v"
            make_flags="${RVAL}"
         fi

         if [ ! -z "${OPTION_LOAD}" ]
         then
            r_concat "${make_flags}" "-l '${OPTION_LOAD}'"
            make_flags="${RVAL}"
         fi
      ;;

      *make)
         makefile="${builddir}/Makefile"
         if [ "${MULLE_FLAG_LOG_VERBOSE}" = 'YES' ]
         then
            r_concat "${make_flags}" "VERBOSE=1"
            make_flags="${RVAL}"
         fi
      ;;
   esac

   if [ ! -z "${OPTION_CORES}" ]
   then
      r_concat "${make_flags}" "-j '${OPTION_CORES}'"
      make_flags="${RVAL}"
   fi

   local run_cmake

   run_cmake='YES'

   # phases need to rerun cmake
   if [ -z "${OPTION_PHASE}" ]
   then
      if ! cmake_files_are_newer_than_makefile "${absprojectdir}" "${makefile}"
      then
         run_cmake='NO'
         log_fluff "Cmake run skipped as no changes to cmake files have been found in \"${absprojectdir}\""
      fi
   fi

   local env_common

   r_mulle_make_env_flags
   env_common="${RVAL}"

   local logfile1
   local logfile2
   local logname2

   r_extensionless_basename "${MAKE}"
   logname2="${RVAL}"

   mkdir_if_missing "${logsdir}"

   r_build_log_name "${logsdir}" "cmake" "${srcdir}" "${configuration}" "${sdk}"
   logfile1="${RVAL}"

   r_build_log_name "${logsdir}" "${logname2}" "${srcdir}" "${configuration}" "${sdk}"
   logfile2="${RVAL}"

   if [ "$MULLE_FLAG_EXEKUTOR_DRY_RUN" = 'YES' ]
   then
      logfile1="/dev/null"
      logfile2="/dev/null"
   else
      if [ "$MULLE_FLAG_LOG_VERBOSE" = 'YES' ]
      then
         logfile1="`safe_tty`"
         logfile2="${logfile1}"
      else
         log_verbose "Build logs will be in \"${logfile1}\" and \"${logfile2}\""
      fi
   fi

   (
      exekutor cd "${builddir}" || fail "failed to enter ${builddir}"

      PATH="${OPTION_PATH:-${PATH}}"
      log_fluff "PATH temporarily set to $PATH"

      if [ "${MULLE_FLAG_LOG_ENVIRONMENT}" = 'YES' ]
      then
         env | sort >&2
      fi

      if [ "${run_cmake}" = 'YES' ]
      then
         if ! logging_redirect_eval_exekutor "${logfile1}" \
                  "${env_common}" \
                  "'${CMAKE}'" -G "'${CMAKE_GENERATOR}'" \
                               "${cmake_flags}" \
                               "'${projectdir}'"
         then
            build_fail "${logfile1}" "cmake"
         fi
      fi

      if ! logging_redirect_eval_exekutor "${logfile2}" \
               "${env_common}" \
               "'${MAKE}'" "${make_flags}" ${maketarget}
      then
         build_fail "${logfile2}" "make"
      fi
   ) || exit 1
}


test_cmake()
{
   log_entry "test_cmake" "$@"

   [ $# -eq 2 ] || internal_fail "api error"

   local configuration="$1"
   local srcdir="$2"

   local projectfile
   local projectdir
   local RVAL

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

   PROJECTFILE="${projectfile}"

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

