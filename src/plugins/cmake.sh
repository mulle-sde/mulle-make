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



platform_cmake_generator()
{
   local makepath="$1"

   local name

   name="`basename -- "${makepath}"`"
   case "${name%.*}" in
      nmake)
         echo "NMake Makefiles"
      ;;

      mingw*|MINGW*)
         echo "MinGW Makefiles"
      ;;

      ninja)
         echo "Ninja"
      ;;

      *)
         case "${MULLE_UNAME}" in
            mingw*)
               echo "MSYS Makefiles"
            ;;

            *)
               echo "Unix Makefiles"
            ;;
         esac
      ;;
   esac
}


find_cmake()
{
   local toolname

   toolname="${OPTION_CMAKE:-${CMAKE:-cmake}}"
   verify_binary "${toolname}" "cmake" "cmake"
}


tools_environment_cmake()
{
   tools_environment_make

   local defaultgenerator

   defaultgenerator="`platform_cmake_generator "${MAKE}"`"
   CMAKE="`find_cmake`"
   CMAKE_GENERATOR="${OPTION_CMAKE_GENERATOR:-${defaultgenerator}}"
}


cmake_sdk_parameter()
{
   local sdk="$1"

   local sdkpath

   case "${MULLE_UNAME}" in
      "darwin")
         sdkpath=`compiler_sdk_parameter "${sdk}"` || exit 1
         if [ ! -z "${sdkpath}" ]
         then
            log_fluff "Set cmake -DCMAKE_OSX_SYSROOT to \"${sdkpath}\""
            echo "-DCMAKE_OSX_SYSROOT='${sdkpath}'"
         fi
      ;;
   esac
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

   cflags="`compiler_cflags_value "${OPTION_CC}" "${configuration}" "NO" `" || exit 1
   cxxflags="`compiler_cxxflags_value "${OPTION_CXX:-${OPTION_CC}}" "${configuration}" "NO" `" || exit 1
   cppflags="`compiler_cppflags_value "${OPTION_INCLUDE_PATH}" `"  || exit 1 # only cmake does OPTION_INCLUDE_PATH here
   ldflags="`compiler_ldflags_value`" || exit 1

   if [ ! -z "${cppflags}" ]
   then
      cflags="`concat "${cflags}" "${cppflags}"`"
      cxxflags="`concat "${cxxflags}" "${cppflags}"`"
   fi

   local rel_project_dir
   local absbuilddir
   local absprojectdir
   local projectdir

   projectdir="`dirname -- "${projectfile}"`"
   absprojectdir="$(simplified_absolutepath "${projectdir}")"
   absbuilddir="$(simplified_absolutepath "${builddir}")"

   rel_project_dir="`projectdir_relative_to_builddir "${absbuilddir}" "${absprojectdir}"`"

   log_debug "projectfile:     ${projectfile}"
   log_debug "projectdir:      ${projectdir}"
   log_debug "absprojectdir:   ${absprojectdir}"
   log_debug "absbuilddir:     ${absbuilddir}"
   log_debug "rel_project_dir: ${rel_project_dir}"
   log_debug "PWD:             ${PWD}"

   local cmake_flags

   cmake_flags="${OPTION_CMAKEFLAGS}"

   local maketarget

   case "${cmd}" in
      build)
         maketarget=
         if [ ! -z "${OPTION_PREFIX}" ]
         then
            cmake_flags="`concat "${cmake_flags}" "-DCMAKE_INSTALL_PREFIX:PATH='${OPTION_PREFIX}'"`"
         fi
      ;;

      install)
         [ -z "${dstdir}" ] && internal_fail "srcdir is empty"
         maketarget="install"
         if [ ! -z "${OPTION_PREFIX}" ]
         then
            cmake_flags="`concat "${cmake_flags}" "-DCMAKE_INSTALL_PREFIX:PATH='${OPTION_PREFIX}'"`"
         else
            cmake_flags="`concat "${cmake_flags}" "-DCMAKE_INSTALL_PREFIX:PATH='${dstdir}'"`"
         fi
      ;;
   esac

   if [ ! -z "${configuration}" ]
   then
      cmake_flags="`concat "${cmake_flags}" "-DCMAKE_BUILD_TYPE='${configuration}'"`"
   fi

   local sdkparameter

   sdkparameter="`cmake_sdk_parameter "${sdk}"`" || exit 1

   if [ -z "${sdkparameter}" ]
   then
      cmake_flags="`concat "${cmake_flags}" "${sdkparameter}"`"
   fi

   if [ ! -z "${OPTION_CC}" ]
   then
      cmake_flags="`concat "${cmake_flags}" "-DCMAKE_C_COMPILER='${OPTION_CC}'"`"
   fi

   if [ ! -z "${OPTION_CXX}" ]
   then
      cmake_flags="`concat "${cmake_flags}" "-DCMAKE_CXX_COMPILER='${OPTION_CXX}'"`"
   fi

   if [ ! -z "${cflags}" ]
   then
      cmake_flags="`concat "${cmake_flags}" "-DCMAKE_C_FLAGS='${cflags}'"`"
   fi
   if [ ! -z "${cxxflags}" ]
   then
      cmake_flags="`concat "${cmake_flags}" "-DCMAKE_CXX_FLAGS='${cxxflags}'"`"
   fi

   if [ ! -z "${ldflags}" ]
   then
      cmake_flags="`concat "${cmake_flags}" "-DCMAKE_SHARED_LINKER_FLAGS='${ldflags}'"`"
      cmake_flags="`concat "${cmake_flags}" "-DCMAKE_EXE_LINKER_FLAGS='${ldflags}'"`"
   fi

   #
   # CMAKE_INCLUDE_PATH doesn't really do what one expects it would
   # it's a setting for the rarely used find_file
   #
   #if [ ! -z "${includelines}" ]
   #then
   #   cmake_dirs="`concat "${cmake_dirs}" "-DCMAKE_INCLUDE_PATH='${includelines}'"`"
   #fi
   if [ ! -z "${OPTION_LIB_PATH}" ]
   then
      local munged

      munged="$(tr ':' ';' <<< "${OPTION_LIB_PATH}")"
      cmake_flags="`concat "${cmake_flags}" "-DCMAKE_LIBRARY_PATH='${munged}'"`"
   fi

   if [ ! -z "${OPTION_FRAMEWORKS_PATH}" ]
   then
      local munged

      munged="$(tr ':' ';' <<< "${OPTION_FRAMEWORKS_PATH}")"
      cmake_flags="`concat "${cmake_flags}" "-DCMAKE_FRAMEWORK_PATH='${munged}'"`"
   fi

   local other_buildsettings

   other_buildsettings="`emit_userdefined_definitions "-D " "=" "=" ""`"
   if [ ! -z "${other_buildsettings}" ]
   then
      cmake_flags="`concat "${cmake_flags}" "${other_buildsettings}"`"
   fi

   local make_flags

   make_flags="${OPTION_MAKEFLAGS}"

   # hackish
   case "${MAKE}" in
      *ninja)
         if [ "${MULLE_FLAG_VERBOSE_MAKE}" = "YES" ]
         then
            make_flags="`concat "${make_flags}" "-v"`"
         fi
      ;;

      *make)
         if [ ! -z "${OPTION_CORES}" ]
         then
            make_flags="-j '${OPTION_CORES}'"
         fi

         if [ "${MULLE_FLAG_VERBOSE_MAKE}" = "YES" ]
         then
            make_flags="`concat "${make_flags}" "VERBOSE=1"`"
         fi
      ;;
   esac

   local env_common

   env_common="`mulle_make_env_flags`"

   local logfile1
   local logfile2

   mkdir_if_missing "${logsdir}"

   logfile1="`build_log_name "${logsdir}" "cmake" "${srcdir}" "${configuration}" "${sdk}"`"
   logfile2="`build_log_name "${logsdir}" "make" "${srcdir}" "${configuration}" "${sdk}"`"

   (
      exekutor cd "${builddir}" || fail "failed to enter ${builddir}"

      if [ "${MULLE_FLAG_LOG_VERBOSE}" = "YES" ]
      then
         logfile1="`safe_tty`"
         logfile2="$logfile1"
      fi
      if [ "${MULLE_FLAG_EXEKUTOR_DRY_RUN}" = "YES" ]
      then
         logfile1="/dev/null"
         logfile2="/dev/null"
      fi
      log_verbose "Build logs will be in \"${logfile1}\" and \"${logfile2}\""

      [ -z "${BUILDPATH}" ] && internal_fail "BUILDPATH not set"
      PATH="${BUILDPATH}"
      log_fluff "PATH temporarily set to $PATH"

      if ! logging_redirect_eval_exekutor "${logfile1}" \
               "${env_common}" \
               "'${CMAKE}'" -G "'${CMAKE_GENERATOR}'" \
                            "${cmake_flags}" \
                            "'${rel_project_dir}'"
      then
         build_fail "${logfile1}" "cmake"
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

   projectfile="`find_nearest_matching_pattern "${srcdir}" "CMakeLists.txt"`"
   if [ ! -f "${projectfile}" ]
   then
      log_fluff "There is no CMakeLists.txt file in \"${srcdir}\""
      return 1
   fi

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

