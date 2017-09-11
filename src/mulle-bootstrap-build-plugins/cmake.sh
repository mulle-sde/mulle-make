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
MULLE_BOOTSTRAP_BUILD_PLUGIN_CMAKE_SH="included"


find_cmake()
{
   local name="$1"

   local toolname

   toolname=`read_build_setting "${name}" "cmake" "cmake"`
   verify_binary "${toolname}" "cmake" "cmake"
}


tools_environment_cmake()
{
   local name="$1"
#   local projectdir="$2"

   tools_environment_make "$@"

   local defaultgenerator

   defaultgenerator="`platform_cmake_generator "${DEFAULTMAKE}"`"
   CMAKE="`find_cmake "${name}"`"
   CMAKE_GENERATOR="`read_build_setting "${name}" "cmake_generator" "${defaultgenerator}"`"
}


cmake_sdk_parameter()
{
   local sdk="$1"

   local sdkpath

   sdkpath=`gcc_sdk_parameter "${sdk}"`
   if [ ! -z "${sdkpath}" ]
   then
      log_fluff "Set cmake -DCMAKE_OSX_SYSROOT to \"${sdkpath}\""
      echo "-DCMAKE_OSX_SYSROOT='${sdkpath}'"
   fi
}


build_cmake_flags()
{
   log_entry "build_cmake_flags" "$@"

   (
      PATH_SEPARATOR=";"
      _build_flags "$@"
   )
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

   local projectfile="$1"
   local configuration="$2"
   local srcdir="$3"
   local builddir="$4"
   local name="$5"
   local sdk="$6"

   local projectdir

   projectdir="`dirname -- "${projectfile}"`"

   local sdkparameter
   local local_cmake_flags
   local local_make_flags

   local_cmake_flags="`read_build_setting "${name}" "CMAKEFLAGS"`"
   sdkparameter="`cmake_sdk_parameter "${sdk}"`"

   if [ ! -z "${CORES}" ]
   then
      local_make_flags="-j ${CORES}"
   fi

   local c_compiler_line
   local cxx_compiler_line

   if [ ! -z "${C_COMPILER}" ]
   then
      c_compiler_line="-DCMAKE_C_COMPILER='${C_COMPILER}'"
   fi
   if [ ! -z "${CXX_COMPILER}" ]
   then
      cxx_compiler_line="-DCMAKE_CXX_COMPILER='${CXX_COMPILER}'"
   fi

   # linker="`read_build_setting "${name}" "LD"`"

   # need this now
   mkdir_if_missing "${builddir}"

   local other_cflags
   local other_cxxflags
   local other_cppflags
   local other_ldflags

   other_cflags="`gcc_cflags_value "${name}"`"
   other_cxxflags="`gcc_cxxflags_value "${name}"`"
   other_cppflags="`gcc_cppflags_value "${name}"`"
   other_ldflags="`gcc_ldflags_value "${name}"`"

   local maketarget

   maketarget="`read_build_setting "${name}" "maketarget" "${MAKETARGET:-install}"`"

   local flaglines
   local mapped

   mapped="`read_build_setting "${name}" "cmake-${configuration}.map" "${configuration}"`"  || exit 1

   flaglines="`build_cmake_flags "${configuration}" \
                                 "${projectdir}" \
                                 "${builddir}" \
                                 "${name}" \
                                 "${sdk}" \
                                 "${mapped}"`" || exit 1

   local cppflags
   local ldflags
   local includelines
   local librarylines
   local frameworklines
   local dependenciesdir

   cppflags="`echo "${flaglines}"        | "${SED}" -n '1p'`"
   ldflags="`echo "${flaglines}"         | "${SED}" -n '2p'`"
   includelines="`echo "${flaglines}"    | "${SED}" -n '6p'`"
   librarylines="`echo "${flaglines}"    | "${SED}" -n '7p'`"
   frameworklines="`echo "${flaglines}"  | "${SED}" -n '8p'`"
   dependenciesdir="`echo "${flaglines}" | "${SED}" -n '9p'`"

   local addictionsdir
   local binpath

   addictionsdir="${PWD}/${REFERENCE_ADDICTIONS_DIR}"
   binpath="${dependenciesdir}/bin"

   # CMAKE_CPP_FLAGS does not exist in cmake
   # so merge into CFLAGS and CXXFLAGS

   if [ -z "${cppflags}" ]
   then
      other_cppflags="`concat "${other_cppflags}" "${cppflags}"`"
   fi

   if [ -z "${other_cppflags}" ]
   then
      other_cflags="`concat "${other_cflags}" "${other_cppflags}"`"
      other_cxxflags="`concat "${other_cxxflags}" "${other_cppflags}"`"
   fi

   if [ -z "${ldflags}" ]
   then
      other_ldflags="`concat "${other_ldflags}" "${ldflags}"`"
   fi

   local cmake_flags

   if [ ! -z "${other_cflags}" ]
   then
      cmake_flags="`concat "${cmake_flags}" "-DCMAKE_C_FLAGS='${other_cflags}'"`"
   fi
   if [ ! -z "${other_cxxflags}" ]
   then
      cmake_flags="`concat "${cmake_flags}" "-DCMAKE_CXX_FLAGS='${other_cxxflags}'"`"
   fi
   if [ ! -z "${other_ldflags}" ]
   then
      cmake_flags="`concat "${cmake_flags}" "-DCMAKE_SHARED_LINKER_FLAGS='${other_ldflags}'"`"
      cmake_flags="`concat "${cmake_flags}" "-DCMAKE_EXE_LINKER_FLAGS='${other_ldflags}'"`"
   fi

   local logfile1
   local logfile2

   mkdir_if_missing "${BUILDLOGS_DIR}"

   logfile1="`build_log_name "cmake" "${name}" "${configuration}" "${sdk}"`"
   logfile2="`build_log_name "make" "${name}" "${configuration}" "${sdk}"`"

#   cmake_keep_builddir="`read_build_setting "${name}" "cmake_keep_builddir" "YES"`"
#   if [ "${cmake_keep_builddir}" != "YES" ]
#   then
#      rmdir_safer "${builddir}"
#   fi
   (
      local owd
      local nativewd

      owd="${PWD}"
      nativewd="`pwd ${BUILD_PWD_OPTIONS}`"

      exekutor cd "${builddir}" || fail "failed to enter ${builddir}"

      # DONT READ CONFIG SETTING IN THIS INDENT
      set -f

      if [ "$MULLE_FLAG_VERBOSE_BUILD" = "YES" ]
      then
         logfile1="`tty`"
         logfile2="$logfile1"
      fi
      if [ "$MULLE_FLAG_EXEKUTOR_DRY_RUN" = "YES" ]
      then
         logfile1="/dev/null"
         logfile2="/dev/null"
      fi

      log_verbose "Build logs will be in \"${logfile1}\" and \"${logfile2}\""

      if [ "${MULLE_FLAG_VERBOSE_BUILD}" = "YES" ]
      then
         local_make_flags="${local_make_flags} VERBOSE=1"
      fi

      local oldpath
      local rval

      [ -z "${BUILDPATH}" ] && internal_fail "BUILDPATH not set"

      oldpath="$PATH"
      PATH="${binpath}:${BUILDPATH}"

      log_fluff "PATH temporarily set to $PATH"

      local prefixbuild

      prefixbuild="`add_cmake_path "${prefixbuild}" "${nativewd}/${BUILD_DEPENDENCIES_DIR}"`"

      local cmake_dirs

      if [ ! -z "${dependenciesdir}" ]
      then
         cmake_dirs="-DDEPENDENCIES_DIR='${dependenciesdir}'"
      fi

      if [ ! -z "${addictionsdir}" ]
      then
         cmake_dirs="`concat "${cmake_dirs}" "-DADDICTIONS_DIR='${addictionsdir}'"`"
      fi

      #
      # CMAKE_INCLUDE_PATH doesn't really do what one expects it would
      # it's a settinh for the rarely used find_file
      #
      #if [ ! -z "${includelines}" ]
      #then
      #   cmake_dirs="`concat "${cmake_dirs}" "-DCMAKE_INCLUDE_PATH='${includelines}'"`"
      #fi

      if [ ! -z "${librarylines}" ]
      then
         cmake_dirs="`concat "${cmake_dirs}" "-DCMAKE_LIBRARY_PATH='${librarylines}'"`"
      fi

      if [ ! -z "${frameworklines}" ]
      then
         cmake_dirs="`concat "${cmake_dirs}" "-DCMAKE_FRAMEWORK_PATH='${frameworklines}'"`"
      fi

      local relative_projectdir

      relative_projectdir="`relative_path_between "${owd}/${projectdir}" "${PWD}"`"
      case "${UNAME}" in
         mingw)
            relative_projectdir="`echo "${relative_projectdir}" | "${TR}" '/' '\\'  2> /dev/null`"
      esac

      logging_redirect_eval_exekutor "${logfile1}" "'${CMAKE}'" \
-G "'${CMAKE_GENERATOR}'" \
"-DMULLE_BOOTSTRAP_VERSION=${MULLE_EXECUTABLE_VERSION}" \
"-DCMAKE_BUILD_TYPE='${mapped}'" \
"-DCMAKE_INSTALL_PREFIX:PATH='${prefixbuild}'"  \
"${sdkparameter}" \
"${cmake_dirs}" \
"${cmake_flags}" \
"${c_compiler_line}" \
"${cxx_compiler_line}" \
"${local_cmake_flags}" \
"${CMAKEFLAGS}" \
"'${relative_projectdir}'"
      rval=$?

      if [ $rval -ne 0 ]
      then
         PATH="${oldpath}"
         build_fail "${logfile1}" "cmake"
      fi

      logging_redirekt_exekutor "${logfile2}" "${MAKE}" ${MAKE_FLAGS} ${local_make_flags} ${maketarget}
      rval=$?

      PATH="${oldpath}"
      [ $rval -ne 0 ] && build_fail "${logfile2}" "make"

      set +f

   ) || exit 1
}


test_cmake()
{
   log_entry "test_cmake" "$@"

   local configuration="$1"
   local srcdir="$2"
   local builddir="$3"
   local name="$4"

   local projectfile
   local projectdir

   projectfile="`find_nearest_matching_pattern "${srcdir}" "CMakeLists.txt"`"
   if [ ! -f "${projectfile}" ]
   then
      log_fluff "There is no CMakeLists.txt file in \"${srcdir}\""
      return 1
   fi
   projectdir="`dirname -- "${projectfile}"`"

   tools_environment_cmake "${name}" "${projectdir}"

   if [ -z "${CMAKE}" ]
   then
      log_warning "Found a CMakeLists.txt, but ${C_RESET}${C_BOLD}cmake${C_WARNING} is not installed"
      return 1
   fi

   if [ -z "${MAKE}" ]
   then
      fail "No make available"
   fi

   log_verbose "Found cmake project file \"${projectfile}\""

   PROJECTFILE="${projectfile}"

   return 0
}
