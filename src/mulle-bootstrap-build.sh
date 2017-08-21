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
MULLE_BOOTSTRAP_BUILD_SH="included"


build_usage()
{
   local defk
   local defc
   local defkk

   defc="`printf "$OPTION_CONFIGURATIONS" | tr '\012' ','`"
   if [ "${OPTION_CLEAN_BEFORE_BUILD}" = "YES" ]
   then
      defk=""
      defkk="(default)"
   else
      defk="(default)"
      defkk=""
   fi

   cat <<EOF >&2
Usage:
   ${MULLE_BOOTSTAP_EXECUTABLE} build [options] [repos]*
EOF

   cat <<EOF >&2
   You may specify the names of the repositories to build.
EOF

   local  repositories

   repositories="`all_repository_stashes`"
   if [ -z "${repositories}" ]
   then
      echo "Currently available repositories are:"
      echo "${repositories}" | sed 's/^/   /'
   fi

# to is experimental and maybe useless
#   --to <name>    :  force rebuild up to and including this project

   cat <<EOF >&2
Options:
   -c <name>      :  configurations to build ($defc), separate with comma
   --from <name>  :  force rebuild from this project
   -k             :  don't clean before building $defk
   -K             :  always clean before building $defkk
   --prefix <dir> :  use <dir> instead of /usr/local
EOF

   case "${UNAME}" in
      mingw*)
         :
      ;;

      *)
         cat <<EOF >&2
   -j             :  number of cores parameter for make (${CORES})
EOF
      ;;
   esac

   echo >&2

   exit 1
}


find_make()
{
   local name="$1"
   local defaultname="${2:-make}"

   local toolname

   toolname=`read_build_setting "${name}" "make" "${defaultname}"`
   verify_binary "${toolname}" "make" "${defaultname}"
}


find_compiler()
{
   local name="$1"
   local srcdir="$2"
   local compiler_name="$3"

   local compiler
   local filename
   local path

   compiler="`read_build_setting "${name}" "${compiler_name}"`"
   if [ -z "${compiler}" -a "${OPTION_USE_CC_CXX}" = "YES" ]
   then
      filename="${srcdir}/.${compiler_name}"
      compiler="`cat "${filename}" 2>/dev/null`"
      if [  ! -z "${compiler}" ]
      then
         log_verbose "Compiler ${C_RESET_BOLD}${compiler_name}${C_VERBOSE} set to ${C_MAGENTA}${C_BOLD}${compiler}${C_VERBOSE} found in \"${filename}\""
      fi
   fi

   case "${UNAME}" in
      mingw)
         if [ "`read_config_setting "mangle_minwg_compiler" "YES"`" = "YES" ]
         then
            compiler="`mingw_mangle_compiler "${compiler}"`"
         fi
      ;;
   esac

   if [ ! -z "${compiler}" ]
   then
      path=`which_binary "${compiler}"`
      if [ -z "${path}" ]
      then
         fail "Compiler \"${compiler}\" not found.
Suggested fix:
   ${C_RESET}${C_BOLD}`suggest_binary_install "${compiler}"`"
      fi
      echo "${compiler}"
   fi
}


tools_environment_common()
{
   local name="$1"
   local srcdir="$2"

   # no problem if those are empty
   C_COMPILER="`find_compiler "${name}" "${srcdir}" CC`"
   CXX_COMPILER="`find_compiler "${name}" "${srcdir}" CXX`"
}


tools_environment_make()
{
   local name="$1"
   local srcdir="$2"

   tools_environment_common "$@"

   local defaultmake

   defaultmake="`platform_make "${C_COMPILER}"`"

   case "${UNAME}" in
      mingw)
         MAKE="`find_make "${name}" "${defaultmake}"`"
      ;;

      darwin)
         MAKE="`find_make "${name}"`"
      ;;

      *)
         MAKE="`find_make "${name}"`"
      ;;
   esac
}


enforce_build_sanity()
{
   if [ -d "${builddir}" -a "${OPTION_CLEAN_BEFORE_BUILD}" = "YES" ]
   then
      log_fluff "Cleaning build directory \"${builddir}\""
      rmdir_safer "${builddir}"
   fi

   # these must not exist
   if [ -d "${BUILD_DEPENDENCIES_DIR}" ]
   then
      fail "A previous build left \"${BUILD_DEPENDENCIES_DIR}\", can't continue"
   fi

   # now make it appear
   mkdir_if_missing "${BUILD_DEPENDENCIES_DIR}"
}


#
# if only one configuration is chosen, make it the default
# if there are multiple configurations, make Release the default
# if Release is not in multiple configurations, then there is no default
#
determine_build_subdir()
{
   log_entry "determine_build_subdir" "$@"

   local configuration="$1"
   local sdk="$2"

   [ -z "$configuration" ] && internal_fail "configuration must not be empty"
   [ -z "$sdk" ]           && internal_fail "sdk must not be empty"

   sdk=`echo "${sdk}" | sed 's/^\([a-zA-Z]*\).*$/\1/g'`

   if [ "${sdk}" = "Default" ]
   then
      if [ "${configuration}" != "Release" ]
      then
         echo "/${configuration}"
      fi
   else
      echo "/${configuration}-${sdk}"
   fi
}


determine_dependencies_subdir()
{
   log_entry "determine_dependencies_subdir" "$@"

   local configuration="$1"
   local sdk="$2"
   local style="$3"

   [ -z "$configuration" ] && internal_fail "configuration must not be empty"
   [ -z "$sdk" ]           && internal_fail "sdk must not be empty"
   [ -z "$BUILD_SDKS" ]    && internal_fail "BUILD_SDKS must not be empty"

   sdk=`echo "${sdk}" | sed 's/^\([a-zA-Z]*\).*$/\1/g'`

   if [ "${style}" = "auto" ]
   then
      style="configuration"

      n_sdks="`echo "${BUILD_SDKS}" | wc -l | awk '{ print $1 }'`"
      if [ $n_sdks -gt 1 ]
      then
         style="configuration-sdk"
      fi
   fi

   case "${style}" in
      "none")
      ;;

      "configuration-strict")
         echo "/${configuration}"
      ;;

      "configuration-sdk-strict")
         echo "/${configuration}-${sdk}"
      ;;

      "configuration-sdk")
         if [ "${sdk}" = "Default" ]
         then
            if [ "${configuration}" != "Release" ]
            then
               echo "/${configuration}"
            fi
         else
            echo "/${configuration}-${sdk}"
         fi
      ;;

      "configuration")
         if [ "${configuration}" != "Release" ]
         then
            echo "/${configuration}"
         fi
      ;;

      *)
         fail "unknown value \"${BUILD_DISPENSE_STYLE}\" for dispense_style"
      ;;
   esac
}


build_fail()
{
   if [ -f "$1" ]
   then
      printf "${C_RED}"
      egrep -B1 -A5 -w "[Ee]rror" "$1" >&2
      printf "${C_RESET}"
   fi

   if [ "$MULLE_TRACE" != "1848" ]
   then
      log_info "Check the build log: ${C_RESET_BOLD}$1${C_INFO}"
   fi
   fail "$2 failed"
}


build_log_name()
{
   local tool="$1"; shift
   local name="$1"; shift

   [ -z "${tool}" ] && internal_fail "tool missing"
   [ -z "${name}" ] && internal_fail "name missing"

   local logfile

   logfile="${BUILDLOGS_DIR}/${name}"

   while [ $# -gt 0 ]
   do
      if [ ! -z "$1" ]
      then
         logfile="${logfile}-$1"
      fi
      [ $# -eq 0 ] || shift
   done

   absolutepath "${logfile}.${tool}.log"
}


_build_flags()
{
   log_entry "_build_flags" "$@"

   local configuration="$1"
   local srcdir="$2"
   local builddir="$3"
   local name="$4"
   local sdk="$5"
   local mapped="$6"

   [ -z "$configuration" ] && internal_fail "configuration must not be empty"
   [ -z "$mapped" ]        && internal_fail "mapped must not be empty"

   local fallback

   fallback="`echo "${OPTION_CONFIGURATIONS}" | tail -1`"
   fallback="`read_build_setting "${name}" "fallback-configuration" "${fallback}"`"

   local mappedsubdir
   local fallbacksubdir
   local suffixsubdir

   suffixsubdir="`determine_dependencies_subdir "${configuration}" "${sdk}" "${OPTION_DISPENSE_STYLE}"`" || exit 1
   mappedsubdir="`determine_dependencies_subdir "${mapped}" "${sdk}" "${OPTION_DISPENSE_STYLE}"`" || exit 1
   fallbacksubdir="`determine_dependencies_subdir "${fallback}" "${sdk}" "${OPTION_DISPENSE_STYLE}"`" || exit 1

   (
      local nativewd
      local owd

      owd="${PWD}"
      nativewd="`pwd ${BUILD_PWD_OPTIONS}`"

      cd "${builddir}"

      local frameworklines
      local librarylines
      local includelines

      frameworklines=
      librarylines=
      includelines=

      if [ ! -z "${suffixsubdir}" ]
      then
         frameworklines="`add_path_if_exists "${frameworklines}" "${nativewd}/${REFERENCE_DEPENDENCIES_DIR}${suffixsubdir}/${FRAMEWORK_DIR_NAME}"`"
         librarylines="`add_path_if_exists "${librarylines}" "${nativewd}/${REFERENCE_DEPENDENCIES_DIR}${suffixsubdir}/${LIBRARY_DIR_NAME}"`"
      fi

      if [ ! -z "${mappedsubdir}" -a "${mappedsubdir}" != "${suffixsubdir}" ]
      then
         frameworklines="`add_path_if_exists "${frameworklines}" "${nativewd}/${REFERENCE_DEPENDENCIES_DIR}${mappedsubdir}/${FRAMEWORK_DIR_NAME}"`"
         librarylines="`add_path_if_exists "${librarylines}" "${nativewd}/${REFERENCE_DEPENDENCIES_DIR}${mappedsubdir}/${LIBRARY_DIR_NAME}"`"
      fi

      if [ ! -z "${fallbacksubdir}" -a "${fallbacksubdir}" != "${suffixsubdir}" -a "${fallbacksubdir}" != "${mappedsubdir}" ]
      then
         frameworklines="`add_path_if_exists "${frameworklines}" "${nativewd}/${REFERENCE_DEPENDENCIES_DIR}${fallbacksubdir}/${FRAMEWORK_DIR_NAME}"`"
         librarylines="`add_path_if_exists "${librarylines}" "${nativewd}/${REFERENCE_DEPENDENCIES_DIR}${fallbacksubdir}/${LIBRARY_DIR_NAME}"`"
      fi

      includelines="`add_path_if_exists "${includelines}" "${nativewd}/${REFERENCE_DEPENDENCIES_DIR}/${HEADER_DIR_NAME}"`"
      includelines="`add_path_if_exists "${includelines}" "${nativewd}/${REFERENCE_ADDICTIONS_DIR}/${HEADER_DIR_NAME}"`"

      librarylines="`add_path_if_exists "${librarylines}" "${nativewd}/${REFERENCE_DEPENDENCIES_DIR}/${LIBRARY_DIR_NAME}"`"
      librarylines="`add_path_if_exists "${librarylines}" "${nativewd}/${REFERENCE_ADDICTIONS_DIR}/${LIBRARY_DIR_NAME}"`"

      frameworklines="`add_path_if_exists "${frameworklines}" "${nativewd}/${REFERENCE_DEPENDENCIES_DIR}/${FRAMEWORK_DIR_NAME}"`"
      frameworklines="`add_path_if_exists "${frameworklines}" "${nativewd}/${REFERENCE_ADDICTIONS_DIR}/${FRAMEWORK_DIR_NAME}"`"

      if [ "${OPTION_ADD_USR_LOCAL}" = "YES" ]
      then
         includelines="`add_path_if_exists "${includelines}" "${USR_LOCAL_INCLUDE}"`"
         librarylines="`add_path_if_exists "${librarylines}" "${USR_LOCAL_LIB}"`"
      fi


   #      cmakemodulepath="\${CMAKE_MODULE_PATH}"
   #      if [ ! -z "${CMAKE_MODULE_PATH}" ]
   #      then
   #         cmakemodulepath="${CMAKE_MODULE_PATH}${PATH_SEPARATOR}${cmakemodulepath}"   # prepend
   #      fi

      local native_includelines
      local native_librarylines
      local native_frameworklines

      native_includelines="${includelines}"
      native_librarylines="${librarylines}"
      native_frameworklines="${frameworklines}"

      local frameworkprefix
      local libraryprefix
      local includeprefix

      frameworkprefix=
      libraryprefix="-L"
      includeprefix="-I"

      case "${UNAME}" in
         darwin)
            frameworkprefix="-F"
         ;;

         mingw)
            native_includelines="`echo "${native_includelines}" | tr '/' '\\'  2> /dev/null`"
            native_librarylines="`echo "${native_librarylines}" | tr '/' '\\'  2> /dev/null`"
            libraryprefix="/LIBPATH:"
            includeprefix="/I"
            frameworklines=
            native_frameworklines=
         ;;

         *)
            frameworklines=
            native_frameworklines=
         ;;
      esac

      local cppflags
      local ldflags
      local path

      # cmake separator
      [ -z "${DEFAULT_IFS}" ] && internal_fail "IFS fail"
      IFS="${PATH_SEPARATOR}"
      for path in ${native_includelines}
      do
         IFS="${DEFAULT_IFS}"
         path="$(sed 's/ /\\ /g' <<< "${path}")"
         cppflags="`concat "${cppflags}" "${includeprefix}${path}"`"
      done

      IFS="${PATH_SEPARATOR}"
      for path in ${native_librarylines}
      do
         IFS="${DEFAULT_IFS}"
         path="$(sed 's/ /\\ /g' <<< "${path}")"
         ldflags="`concat "${ldflags}" "${libraryprefix}${path}"`"
      done

      IFS="${PATH_SEPARATOR}"
      for path in ${native_frameworklines}
      do
         IFS="${DEFAULT_IFS}"
         path="$(sed 's/ /\\ /g' <<< "${path}")"
         cppflags="`concat "${cppflags}" "${frameworkprefix}${path}"`"
         ldflags="`concat "${ldflags}" "${frameworkprefix}${path}"`"
      done
      IFS="${DEFAULT_IFS}"

      #
      # the output one line each
      #
      echo "${cppflags}"
      echo "${ldflags}"
      echo "${native_includelines}"
      echo "${native_librarylines}"
      echo "${native_frameworklines}"

      echo "${includelines}"
      echo "${librarylines}"
      echo "${frameworklines}"
      echo "${nativewd}/${REFERENCE_DEPENDENCIES_DIR}${suffixsubdir}"
   )
}


build_unix_flags()
{
   log_entry "build_unix_flags" "$@"

   _build_flags "$@"
}


#
# Code I didn't want to throw away really
# In general just use "public_headers" or
# "private_headers" and set them to a /usr/local/include/whatever
#
create_mangled_header_path()
{
   local key="$1"
   local name="$2"
   local default="$3"

   local headers
#   local prefix

   headers="`xcode_get_setting "${key}" $*`"
   log_fluff "${key} read as \"${headers}\""

   case "${headers}" in
      /*)
      ;;

      ./*|../*)
         log_warning "relative path \"${headers}\" as header path ???"
      ;;

      "")
         headers="${default}"
      ;;

      *)
         headers="/${headers}"
      ;;
   esac

   # prefix=""
   read_yes_no_build_setting "${name}" "xcode_mangle_include_prefix"
   if [ $? -ne 0 ]
   then
      headers="`remove_absolute_path_prefix_up_to "${headers}" "include"`"
      # prefix="${HEADER_DIR_NAME}"
   fi

   if read_yes_no_build_setting "${name}" "xcode_mangle_header_dash"
   then
      headers="`echo "${headers}" | tr '-' '_'`"
   fi

   echo "${headers}"
}


fixup_header_path()
{
   local key
   local setting_key
   local default
   local name

   key="$1"
   shift
   setting_key="$1"
   shift
   name="$1"
   shift
   default="$1"
   shift

   headers="`read_build_setting "${name}" "${setting_key}"`"
   if [ "$headers" = "" ]
   then
      read_yes_no_build_setting "${name}" "xcode_mangle_header_paths"
      if [ $? -ne 0 ]
      then
         return 1
      fi

      headers="`create_mangled_header_path "${key}" "${name}" "${default}"`"
   fi

   log_fluff "${key} set to \"${headers}\""

   echo "${headers}"
}



build_with_configuration_sdk_preferences()
{
   log_entry "build_with_configuration_sdk_preferences" "$@"

   local name="$1"; shift
   local configuration="$1"; shift
   local sdk="$1" ; shift
   local preferences="$1" ; shift

   if [ "/${configuration}" = "/${LIBRARY_DIR_NAME}" -o "/${configuration}" = "${HEADER_DIR_NAME}" -o "/${configuration}" = "${FRAMEWORK_DIR_NAME}" ]
   then
      fail "You are just asking for trouble naming your configuration \"${configuration}\"."
   fi

   if [ "${configuration}" = "lib" -o "${configuration}" = "include" -o "${configuration}" = "Frameworks" ]
   then
      fail "You are just asking for major trouble naming your configuration \"${configuration}\"."
   fi

   # always build into fully qualified
   local build_subdir
   local builddir

   build_subdir="`determine_build_subdir "${configuration}" "${sdk}"`" || exit 1
   builddir="${CLONESBUILD_DIR}${build_subdir}/${name}"

   enforce_build_sanity "${builddir}"

   local project
   local rval
   local WASXCODE
   local PARAMETER

   rval=1
   for preference in ${preferences}
   do
      WASXCODE="NO"
      PARAMETER=
      test_${preference} "${configuration}" "${srcdir}" "${builddir}" "${name}"
      if [ $? -eq 0 ]
      then
         build_${preference} "${PARAMETER}" "${configuration}" "${srcdir}" "${builddir}" "${name}" "${sdk}"
         if [ $? -ne 0 ]
         then
            internal_fail "$build_${preference} should exit on failure and not return"
         fi
         rval=0
         break
      fi
   done

   if [ $rval -eq 0 ]
   then
      local depend_subdir

      [ -z "${MULLE_BOOTSTRAP_DISPENSE_SH}" ] && . mulle-bootstrap-dispense.sh

      depend_subdir="`determine_dependencies_subdir "${configuration}" "${sdk}" "${OPTION_DISPENSE_STYLE}"`" || exit 1
      collect_and_dispense_product "${name}" "${build_subdir}" "${depend_subdir}" "${WASXCODE}"
   fi

   return $rval
}


load_build_plugins()
{
   local preferences="$1"

   log_fluff "Loading build plugins..."

   local preference="$1"
   local upcase
   local plugindefine
   local pluginpath

   IFS="
"
   for preference in ${preferences}
   do
      IFS="${DEFAULT_IFS}"

      upcase="`tr '[a-z]' '[A-Z]' <<< "${preference}"`"
      plugindefine="MULLE_BOOTSTRAP_BUILD_PLUGIN_${upcase}_SH"

      if [ -z "`eval echo \$\{${plugindefine}\}`" ]
      then
         pluginpath="${MULLE_BOOTSTRAP_LIBEXEC_PATH}/mulle-bootstrap-build-plugins/${preference}.sh"
         if [ ! -f "${pluginpath}" ]
         then
            log_verbose "No Build plugin for \"${preference}\" found"
            continue
         fi

         . "${pluginpath}"

         if [ "`type -t "test_${preference}"`" != "function" ]
         then
            fail "Build plugin \"${pluginpath}\" has no \"test_${preference}\" function"
         fi

         if [ "`type -t "build_${preference}"`" != "function" ]
         then
            fail "Build plugin \"${pluginpath}\" has no \"build_${preference}\" function"
         fi

         log_verbose "Build plugin for \"${preference}\" loaded"
      fi
      AVAILABLE_PLUGINS="`add_line "${AVAILABLE_PLUGINS}" "${preference}"`"
   done

   IFS="${DEFAULT_IFS}"
}


build()
{
   log_entry "build" "$@"

   local name
   local srcdir

   name="$1"
   srcdir="$2"

   [ "${name}" != "${REPOS_DIR}" ] || internal_fail "missing repo argument (${srcdir})"

   log_verbose "Building ${name} ..."

   local preferences
   local directory

   #
   # repo may override how it wants to be build
   #
   preferences="`read_build_setting "${name}" "build_preferences"`"
   directory="`read_build_setting "${name}" "srcdir"`"
   srcdir="`add_component "${srcdir}" "${directory}"`"

   if [ -z "${preferences}" ]
   then
      case "${UNAME}" in
         darwin)
            preferences="`read_config_setting "build_preferences" "script
cmake
configure
xcodebuild"`"
         ;;


         *)
            preferences="`read_config_setting "build_preferences" "script
cmake
configure"`"
         ;;
      esac
   fi

   log_fluff "Build preferences for ${UNAME} are: `echo ${preferences}`"

   local AVAILABLE_PLUGINS=

   load_build_plugins "${preferences}" # can't be subshell !

   if [ -z "${AVAILABLE_PLUGINS}" ]
   then
      fail "Don't know how to build \"${name}\", there are no plugins available for `echo ${preferences}`"
   fi

   local configurations
   local configuration
   local sdks
   local sdk

   # need uniform SDK for our builds
   sdks=`read_build_setting "${name}" "sdks" "${OPTION_SDKS}"`

   [ ! -z "${sdks}" ] || fail "setting \"sdks\" must at least contain \"Default\" to build anything"

   # settings can override the commandline default
   configurations="`read_build_setting "${name}" "configurations" "${OPTION_CONFIGURATIONS}"`"

   # "export" some globals
   local BUILD_CONFIGURATIONS
   local BUILD_SDKS

   BUILD_CONFIGURATIONS="${configurations}"
   BUILD_SDKS="${sdks}"

   for sdk in ${sdks}
   do
      # remap macosx to Default, as EFFECTIVE_PLATFORM_NAME will not be appended by Xcode
      case "${UNAME}" in
         darwin)
            if [ "$sdk" = "macosx" ]
            then
               sdk="Default"
            fi
         ;;
      esac

      for configuration in ${configurations}
      do
         build_with_configuration_sdk_preferences "${name}" \
                                                  "${configuration}" \
                                                  "${sdk}" \
                                                  "${AVAILABLE_PLUGINS}"
         if [ $? -ne 0 ]
         then
            fail "Don't know how to build ${name}"
         fi
      done
   done
}


#
# ${DEPENDENCIES_DIR} is split into
#
#  REFERENCE_DEPENDENCIES_DIR and
#  BUILD_DEPENDENCIES_DIR
#
# above this function, noone should access ${DEPENDENCIES_DIR}
#
build_wrapper()
{
   log_entry "build_wrapper" "$@"

   local srcdir
   local name

   name="$1"
   srcdir="$2"

   REFERENCE_ADDICTIONS_DIR="${ADDICTIONS_DIR}"
   REFERENCE_DEPENDENCIES_DIR="${DEPENDENCIES_DIR}"
   BUILD_DEPENDENCIES_DIR="${DEPENDENCIES_DIR}/tmp"

   DEPENDENCIES_DIR="WRONG_DONT_USE_DEPENDENCIES_DIR_DURING_BUILD"
   ADDICTIONS_DIR="WRONG_DONT_USE_ADDICTIONS_DIR_DURING_BUILD"

   log_fluff "Setting up BUILD_DEPENDENCIES_DIR as \"${BUILD_DEPENDENCIES_DIR}\""

   if [ "${COMMAND}" != "ibuild" -a -d "${BUILD_DEPENDENCIES_DIR}" ]
   then
      log_fluff "Cleaning up orphaned \"${BUILD_DEPENDENCIES_DIR}\""
      rmdir_safer "${BUILD_DEPENDENCIES_DIR}"
   fi

   #
   # move dependencies we have so far away into safety,
   # need that path for includes though
   #

   run_build_settings_script "pre-build" \
                             "${name}" \
                             "${srcdir}"

   build "${name}" "${srcdir}"

   run_build_settings_script "post-build" \
                             "${name}" \
                             "${srcdir}"

   if [ "${COMMAND}" != "ibuild"  ]
   then
      log_fluff "Remove \"${BUILD_DEPENDENCIES_DIR}\""
      rmdir_safer "${BUILD_DEPENDENCIES_DIR}"
   else
      log_fluff "Not removing \"${BUILD_DEPENDENCIES_DIR}\" because of \"${COMMAND}\""
   fi

   DEPENDENCIES_DIR="${REFERENCE_DEPENDENCIES_DIR}"
   ADDICTIONS_DIR="${REFERENCE_ADDICTIONS_DIR}"

   # for mulle-bootstrap developers
   REFERENCE_DEPENDENCIES_DIR="WRONG_DONT_USE_REFERENCE_DEPENDENCIES_DIR_AFTER_BUILD"
   BUILD_DEPENDENCIES_DIR="WRONG_DONT_USE_BUILD_DEPENDENCIES_DIR_AFTER_BUILD"
}


# keep until "to" but excluding it
# cut stuff until "to"
# keep "to" and keep rest

force_rebuild()
{
   log_entry "force_rebuild" "$@"

   local from="$1"
   local to="$2"

   remove_file_if_present "${REPOS_DIR}/.build_started"

   # if nothing's build yet, fine with us
   if [ ! -f "${REPOS_DIR}/.build_done" ]
   then
      log_fluff "Nothing has been built yet"
      return
   fi

   if [ -z "${from}" -a -z "${to}" ]
   then
      remove_file_if_present "${REPOS_DIR}/.build_done"
      return
   fi

   #
   # keep entries above parameter
   # os x doesn't have 'Q'
   # also q and i doesn't work on OS X <sigh>
   #
   local tmpfile

   [ -z "${MULLE_BOOTSTRAP_SNIP_SH}" ] && . mulle-bootstrap-snip.sh

   tmpfile="`exekutor mktemp "mulle-bootstrap.XXXXXXXX"`" || exit 1

   redirect_exekutor "${tmpfile}" snip_from_to_file "${from}" "${to}" "${REPOS_DIR}/.build_done"
   exekutor mv "${tmpfile}" "${REPOS_DIR}/.build_done"

   log_debug ".build_done=`cat "${REPOS_DIR}/.build_done"`"
}


build_if_alive()
{
   log_entry "build_if_alive" "$@"

   local name
   local stashdir

   name="$1"
   stashdir="$2"

   local xdone
   local zombie

   zombie="`dirname -- "${stashdir}"`/.zombies/${name}"
   if [ -e "${zombie}" ]
   then
      log_warning "Ignoring zombie repo ${name} as \"${zombie}${C_WARNING} exists"
   else
      xdone="`/bin/echo "${BUILT}" | grep -x "${name}"`"
      if [ "$xdone" = "" ]
      then
         build_wrapper "${name}" "${stashdir}"

         # memorize what we build
         merge_line_into_file "${REPOS_DIR}/.build_done" "${name}"

         BUILT="${name}
${BUILT}"
      else
         log_fluff "Ignoring \"${name}\" as already built."
      fi
   fi
}


build_stashes()
{
   log_entry "build_stashes" "$@"

   local name

   IFS="
"
   for name in `ls -1d "${STASHES_DEFAULT_DIR}"/*.failed 2> /dev/null`
   do
      IFS="${DEFAULT_IFS}"
      if [ -d "${name}" ]
      then
         fail "failed checkout \"${name}\" detected, can't continue"
      fi
   done
   IFS="${DEFAULT_IFS}"

   run_root_settings_script "pre-build"

   #
   # build_order is created by refresh
   #
   local stashdir
   local stashnames

   BUILT=""

   if [ "$#" -eq 0 ]
   then
      #
      # don't redo builds (if no names are specified)
      #

      BUILT="`read_setting "${REPOS_DIR}/.build_done"`"
      stashnames="`read_root_setting "build_order"`"
      if [ ! -z "${stashnames}" ]
      then
         IFS="
"
         for name in ${stashnames}
         do
            IFS="${DEFAULT_IFS}"

            stashdir="`stash_of_repository "${REPOS_DIR}" "${name}"`"
            if [ -z "${stashdir}" ]
            then
               fail "${REPOS_DIR}/${name} is missing, that shouldn't have happened. Maybe it's time to dist clean"
            fi

            if [ -d "${stashdir}" ]
            then
               build_if_alive "${name}" "${stashdir}" || exit  1
            else
               if [ "${OPTION_CHECK_USR_LOCAL_INCLUDE}" = "YES" ] && has_usr_local_include "${name}"
               then
                  log_info "${C_MAGENTA}${C_BOLD}${name}${C_INFO} is a system library, so not building it"
                  :
               else
                  if [ ! -z "${stashdir}" ]
                  then
                     fail "Build failed for repository \"${name}\": not found in (\"${stashdir}\") ($PWD)"
                  else
                     log_fluff "Ignoring \"${name}\" as \"${stashdir}\" is missing, but it is not required"
                  fi
               fi
            fi
         done
      fi
   else
      for name in "$@"
      do
         stashdir="`stash_of_repository "${REPOS_DIR}" "${name}"`"

         if [ -d "${stashdir}" ]
         then
            build_if_alive "${name}" "${stashdir}"|| exit 1
         else
            if [ "${OPTION_CHECK_USR_LOCAL_INCLUDE}" = "YES" ] && has_usr_local_include "${name}"
            then
               log_info "${C_MAGENTA}${C_BOLD}${name}${C_INFO} is a system library, so not building it"
               :
            else
               if [ ! -z "${stashdir}" ]
               then
                  fail "Build failed for repository \"${name}\": not found in (\"${stashdir}\") ($PWD)"
               else
                  fail "Unknown repo \"${name}\", possibly not a required one."
               fi
            fi
         fi
      done
   fi

   IFS="${DEFAULT_IFS}"

   run_root_settings_script "post-build"
}


have_tars()
{
   tarballs=`read_root_setting "tarballs"`
   [ ! -z "${tarballs}" ]
}


install_tars()
{
   log_entry "install_tars" "$@"

   local tarballs
   local tar

   tarballs=`read_root_setting "tarballs" | sort | sort -u`
   if [ "${tarballs}" = "" ]
   then
      return 0
   fi

   IFS="
"
   for tar in ${tarballs}
   do
      IFS="${DEFAULT_IFS}"

      if [ ! -f "$tar" ]
      then
         fail "tarball \"$tar\" not found"
      else
         mkdir_if_missing "${DEPENDENCIES_DIR}"
         log_info "Installing tarball \"${tar}\""
         exekutor tar -xz ${TARFLAGS} -C "${DEPENDENCIES_DIR}" -f "${tar}" || fail "failed to extract ${tar}"
      fi
   done
   IFS="${DEFAULT_IFS}"
}


build_main()
{
   local  clean

   log_entry "::: build begin :::" "$@"

   [ -z "${DEFAULT_IFS}" ] && internal_fail "IFS fail"
   [ -z "${MULLE_BOOTSTRAP_SETTINGS_SH}" ]        && . mulle-bootstrap-settings.sh
   [ -z "${MULLE_BOOTSTRAP_COMMON_SETTINGS_SH}" ] && . mulle-bootstrap-common-settings.sh
   [ -z "${MULLE_BOOTSTRAP_REPOSITORIES_SH}" ]    && . mulle-bootstrap-repositories.sh

   local OPTION_CLEAN_BEFORE_BUILD
   local OPTION_CHECK_USR_LOCAL_INCLUDE
   local OPTION_CONFIGURATIONS
   local OPTION_SDKS
   local OPTION_ADD_USR_LOCAL
   local OPTION_USE_CC_CXX
   local OPTION_FROM
   local OPTION_TO
   local OPTION_DISPENSE_STYLE  # keep empty

   OPTION_CHECK_USR_LOCAL_INCLUDE="`read_config_setting "check_usr_local_include" "NO"`"
   OPTION_USE_CC_CXX="`read_config_setting "use_cc_cxx" "YES"`"

   #
   # it is useful, that fetch understands build options and
   # ignores them
   #
   while [ $# -ne 0 ]
   do
      case "$1" in
         -c|--configuration|--configurations)
            [ $# -eq 1 ] && fail "argument for $1 is missing"
            shift

            OPTION_CONFIGURATIONS="`printf "%s" "$1" | tr ',' '\012'`"
            ;;

         -cs|--check-usr-local-include)
            # set environment to be picked up by config
            OPTION_CHECK_USR_LOCAL_INCLUDE="YES"
         ;;

         --debug)
            OPTION_CONFIGURATIONS="Debug"
            OPTION_DISPENSE_STYLE="none"
         ;;

         --from)
            [ $# -eq 1 ] && fail "argument for $1 is missing"
            shift

            OPTION_FROM="$1"
         ;;

         -j|--cores)
            [ $# -eq 1 ] && fail "argument for $1 is missing"
            shift

            case "${UNAME}" in
               mingw)
                  build_usage
               ;;
            esac

            CORES="$1"
         ;;

         -k|--no-clean)
            OPTION_CLEAN_BEFORE_BUILD=
         ;;

         -K|--clean)
            OPTION_CLEAN_BEFORE_BUILD="YES"
         ;;

         --prefix)
            [ $# -eq 1 ] && fail "argument for $1 is missing"
            shift

            USR_LOCAL_INCLUDE="$1/include"
            USR_LOCAL_LIB="$1/lib"
         ;;

         --release)
            OPTION_CONFIGURATIONS="Release"
            OPTION_DISPENSE_STYLE="none"
         ;;

         -sdk|--sdks)
            [ $# -eq 1 ] && fail "argument for $1 is missing"
            shift

            OPTION_SDKS="`printf "%s" "$1" | tr ',' '\012'`"
         ;;


         --to)
            [ $# -eq 1 ] && fail "argument for $1 is missing"
            shift
            OPTION_TO="$1"
         ;;

         --use-prefix-libraries)
            OPTION_ADD_USR_LOCAL=YES
         ;;

         # TODO: outdated!
         # fetch options, are just ignored (need to update this!)
         -e|--embedded-only|-es|--embedded-symlinks|-l|--symlinks)
            :
         ;;

         -*)
            log_error "${MULLE_EXECUTABLE_FAIL_PREFIX}: Unknown build option $1"
            build_usage
         ;;

         ""|*)
            break
         ;;
      esac

      shift
      continue
   done


   #
   # START
   #
   if [ ! -f "${BOOTSTRAP_DIR}.auto/build_order" ]
   then
      log_info "No repositories fetched, so nothing to build."
      return 0  # not an error really, maybe only embedded stuff here
   fi

   build_complete_environment

   [ -z "${MULLE_BOOTSTRAP_COMMAND_SH}" ] && . mulle-bootstrap-command.sh
   [ -z "${MULLE_BOOTSTRAP_GCC_SH}" ]     && . mulle-bootstrap-gcc.sh
   [ -z "${MULLE_BOOTSTRAP_SCRIPTS_SH}" ] && . mulle-bootstrap-scripts.sh

   case "${ADDICTIONS_DIR}" in
      /*|~*)
         internal_fail "ADDICTIONS_DIR must not be an absolute path"
      ;;
   esac
   case "${DEPENDENCIES_DIR}" in
      /*|~*)
         internal_fail "DEPENDENCIES_DIR must not be an absolute path"
      ;;
   esac


   #
   #
   #
   if [ ! -f "${REPOS_DIR}/.build_done" ]
   then
      remove_file_if_present "${REPOS_DIR}/.build_done.orig"
      _create_file_if_missing "${REPOS_DIR}/.build_done"

      log_fluff "Cleaning dependencies directory as \"${DEPENDENCIES_DIR}\""
      rmdir_safer "${DEPENDENCIES_DIR}"
   else
      if [ "${MULLE_FLAG_MAGNUM_FORCE}" != "NONE" ] || \
         [ ! -z "${OPTION_FROM}" -o ! -z "${OPTION_TO}" ]
      then
         force_rebuild "${OPTION_FROM}" "${OPTION_TO}"
      fi
   fi

   # parameter ? partial build!

   if [ -d "${DEPENDENCIES_DIR}" ]
   then
      log_fluff "Unprotecting \"${DEPENDENCIES_DIR}\" (as this is a partial build)."
      exekutor chmod -R u+w "${DEPENDENCIES_DIR}"
      if have_tars
      then
         log_verbose "Tars have not been installed, as \"${DEPENDENCIES_DIR}\" already exists."
      fi
   else
      install_tars "$@"
   fi

   build_stashes "$@"

   if [ -d "${DEPENDENCIES_DIR}" ]
   then
      write_protect_directory "${DEPENDENCIES_DIR}"
   else
      log_fluff "No dependencies have been generated"

      remove_file_if_present "${REPOS_DIR}/.build_done.orig"
      remove_file_if_present "${REPOS_DIR}/.build_done"
   fi

   log_debug "::: build end :::"
}


