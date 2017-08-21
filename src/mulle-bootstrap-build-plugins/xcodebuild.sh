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
MULLE_BOOTSTRAP_BUILD_PLUGIN_XCODEBUILD_SH="included"


find_xcodebuild()
{
   local name="$1"

   local toolname

   toolname=`read_build_setting "${name}" "xcodebuild" "xcodebuild"`
   verify_binary "${toolname}" "xcodebuild" "xcodebuild"
}


tools_environment_xcodebuild()
{
   local name="$1"
#   local projectdir="$2"

   tools_environment_common "$@"

   XCODEBUILD="`find_xcodebuild "${name}"`"
}


_xcode_get_setting()
{
   eval_exekutor "xcodebuild -showBuildSettings $*" || fail "failed to read xcode settings"
}


xcode_get_setting()
{
   local key=$1; shift

   _xcode_get_setting "$@" | egrep "^[ ]*${key}" | sed 's/^[^=]*=[ ]*\(.*\)/\1/'

   return 0
}


xcode_fixup_header_path()
{
   local key="$1" ; shift
   local setting_key="$1" ; shift
   local name="$1"; shift
   local default="$1" ; shift

   headers="`read_build_setting "${name}" "${setting_key}"`"

   # headers setting overrides
   if [ -z "${headers}" ]
   then
      if ! read_yes_no_build_setting "${name}" "xcode_mangle_header_paths"
      then
         return
      fi

      headers="`create_mangled_header_path "${key}" "${name}" "${default}"`"
   fi

   log_fluff "${key} set to \"${headers}\""

   echo "${headers}"
}


_build_xcodebuild()
{
   log_entry "_build_xcodebuild" "$@"

   local projectfile="$1"
   local configuration="$2"
   local srcdir="$3"
   local builddir="$4"
   local name="$5"
   local sdk="$6"
   local schemename="$7"
   local targetname="$8"

   [ ! -z "${configuration}" ] || internal_fail "configuration is empty"
   [ ! -z "${srcdir}" ]        || internal_fail "srcdir is empty"
   [ ! -z "${builddir}" ]      || internal_fail "builddir is empty"
   [ ! -z "${name}" ]          || internal_fail "name is empty"
   [ ! -z "${sdk}" ]           || internal_fail "sdk is empty"
   [ ! -z "${projectfile}" ]   || internal_fail "project is empty"

   local projectdir

   projectdir="`dirname -- "${projectfile}"`"

   local mapped
   local fallback

   fallback="`echo "${OPTION_CONFIGURATIONS}" | tail -1`"
   fallback="`read_build_setting "${name}" "fallback-configuration" "${fallback}"`"

   mapped=`read_build_setting "${name}" "${configuration}.map" "${configuration}"`
   [ -z "${mapped}" ] && internal_fail "mapped configuration is empty"

   local hackish
   local targetname
   local suffix

   suffix="${mapped}"
   if [ "${sdk}" != "Default" ]
   then
      hackish="`echo "${sdk}" | sed 's/^\([a-zA-Z]*\).*$/\1/g'`"
      suffix="${suffix}-${hackish}"
   else
      sdk=
   fi

#   create_dummy_dirs_against_warnings "${mapped}" "${suffix}"

   local mappedsubdir
   local fallbacksubdir
   local suffixsubdir
   local binpath

   suffixsubdir="`determine_dependencies_subdir "${configuration}" "${sdk}" "${OPTION_DISPENSE_STYLE}"`" || exit 1
   mappedsubdir="`determine_dependencies_subdir "${mapped}" "${sdk}" "${OPTION_DISPENSE_STYLE}"`" || exit 1
   fallbacksubdir="`determine_dependencies_subdir "${fallback}" "${sdk}" "${OPTION_DISPENSE_STYLE}"`" || exit 1
   binpath="${PWD}/${REFERENCE_DEPENDENCIES_DIR}${suffixsubdir}/bin"

   local xcode_proper_skip_install
   local skip_install

   skip_install=
   xcode_proper_skip_install=`read_build_setting "${name}" "xcode_proper_skip_install" "NO"`
   if [ "$xcode_proper_skip_install" != "YES" ]
   then
      skip_install="SKIP_INSTALL=NO"
   fi

   #
   # xctool needs schemes, these are often autocreated, which xctool cant do
   # xcodebuild can just use a target
   # xctool is by and large useless fluff IMO
   #
   if [ "${TOOLNAME}" = "xctool"  -a "${schemename}" = ""  ]
   then
      if [ ! -z "$targetname" ]
      then
         schemename="${targetname}"
         targetname=
      else
         cat <<EOF >&2
Please specify a scheme to compile in ${BOOTSTRAP_DIR}/${name}/SCHEME for
xctool and be sure that this scheme exists and is shared. Or delete
${HOME}/.mulle-bootstrap/xcodebuild and use xcodebuild (preferred).
EOF
         exit 1
      fi
   fi

   local key
   local aux
   local value
   local keys

   aux=
   keys=`all_build_flag_keys "${name}"`
   for key in ${keys}
   do
      value=`read_build_setting "${name}" "${key}"`
      aux="${aux} ${key}=${value}"
   done

   # now don't load any settings anymoe
   local owd
   local command

   if [ "${MULLE_FLAG_EXEKUTOR_DRY_RUN}" = "YES" ]
   then
      command=-showBuildSettings
   else
      command=install
   fi

   #
   # headers are complicated, the preference is to get it uniform into
   # dependencies/include/libraryname/..
   #

   local public_headers
   local private_headers
   local default

   default="/include/${name}"
   public_headers="`xcode_fixup_header_path "PUBLIC_HEADERS_FOLDER_PATH" "xcode_public_headers" "${name}" "${default}" ${arguments}`"
   default="/include/${name}/private"
   private_headers="`xcode_fixup_header_path "PRIVATE_HEADERS_FOLDER_PATH" "xcode_private_headers" "${name}" "${default}" ${arguments}`"

   local logfile

   mkdir_if_missing "${BUILDLOGS_DIR}"

   logfile="`build_log_name "${TOOLNAME}" "${name}" "${configuration}" "${targetname}" "${schemename}" "${sdk}"`" || exit 1

   set -f

   arguments=""
   if [ ! -z "${projectname}" ]
   then
      arguments="${arguments} -project \"${projectname}\""
   fi
   if [ ! -z "${sdk}" ]
   then
      arguments="${arguments} -sdk \"${sdk}\""
   fi
   if [ ! -z "${schemename}" ]
   then
      arguments="${arguments} -scheme \"${schemename}\""
   fi
   if [ ! -z "${targetname}" ]
   then
      arguments="${arguments} -target \"${targetname}\""
   fi
   if [ ! -z "${mapped}" ]
   then
      arguments="${arguments} -configuration \"${mapped}\""
   fi

# an empty xcconfig is nice, because it acts as a reset for
   local xcconfig

   xcconfig=`read_build_setting "${name}" "xcconfig"`
   if [ ! -z "${xcconfig}" ]
   then
      arguments="${arguments} -xcconfig \"${xcconfig}\""
   fi

   local other_cflags
   local other_cxxflags
   local other_ldflags

   other_cflags="`gcc_cflags_value "${name}"`"
   other_cxxflags="`gcc_cxxflags_value "${name}"`"
   other_ldflags="`gcc_ldflags_value "${name}"`"

   if [ ! -z "${other_cflags}" ]
   then
      other_cflags="OTHER_CFLAGS=${other_cflags}"
   fi
   if [ ! -z "${other_cxxflags}" ]
   then
      other_cxxflags="other_cxxflags=${other_cxxflags}"
   fi
   if [ ! -z "${other_ldflags}" ]
   then
      other_ldflags="OTHER_LDFLAGS=${other_ldflags}"
   fi

   owd=`pwd`
   exekutor cd "${projectdir}" || exit 1

      # DONT READ CONFIG SETTING IN THIS INDENT
      if [ "${MULLE_FLAG_VERBOSE_BUILD}" = "YES" ]
      then
         logfile="`tty`"
      fi
      if [ "$MULLE_FLAG_EXEKUTOR_DRY_RUN" = "YES" ]
      then
         logfile="/dev/null"
      fi

      log_verbose "Build log will be in: ${C_RESET_BOLD}${logfile}${C_VERBOSE}"

      # manually point xcode to our headers and libs
      # this is like manually doing xcode-setup
      local dependencies_framework_search_path
      local dependencies_header_search_path
      local dependencies_lib_search_path
      local inherited
      local path
      local escaped

      #
      # TODO: need to figure out the correct mapping here
      #
      inherited="`xcode_get_setting HEADER_SEARCH_PATHS ${arguments}`"
      path=`combined_escaped_search_path \
"${owd}/${REFERENCE_DEPENDENCIES_DIR}/${HEADER_DIR_NAME}" \
"${owd}/${REFERENCE_ADDICTIONS_DIR}/${HEADER_DIR_NAME}"`
      if [ -z "${inherited}" ]
      then
         dependencies_header_search_path="${path}"
      else
         dependencies_header_search_path="${path} ${inherited}"
      fi

      inherited="`xcode_get_setting LIBRARY_SEARCH_PATHS ${arguments}`"
      path=`combined_escaped_search_path_if_exists \
"${owd}/${REFERENCE_DEPENDENCIES_DIR}${mappedsubdir}/${LIBRARY_DIR_NAME}" \
"${owd}/${REFERENCE_DEPENDENCIES_DIR}${fallbacksubdir}/${LIBRARY_DIR_NAME}" \
"${owd}/${REFERENCE_DEPENDENCIES_DIR}/${LIBRARY_DIR_NAME}" \
"${owd}/${REFERENCE_ADDICTIONS_DIR}/${LIBRARY_DIR_NAME}"`
      if [ ! -z "$sdk" ]
      then
         escaped="`escaped_spaces "${owd}/${REFERENCE_DEPENDENCIES_DIR}${mappedsubdir}/${LIBRARY_DIR_NAME}"'-$(EFFECTIVE_PLATFORM_NAME)'`"
         path="${escaped} ${path}" # prepend
      fi
      if [ -z "${inherited}" ]
      then
         dependencies_lib_search_path="${path}"
      else
         dependencies_lib_search_path="${path} ${inherited}"
      fi

      if [ "${OPTION_ADD_USR_LOCAL}" = "YES" ]
      then
         dependencies_header_search_path="${path} ${USR_LOCAL_INCLUDE}"
         dependencies_lib_search_path="${path} ${USR_LOCAL_LIB}"
      fi

      inherited="`xcode_get_setting FRAMEWORK_SEARCH_PATHS ${arguments}`"
      path=`combined_escaped_search_path_if_exists \
"${owd}/${REFERENCE_DEPENDENCIES_DIR}${mappedsubdir}/${FRAMEWORK_DIR_NAME}" \
"${owd}/${REFERENCE_DEPENDENCIES_DIR}${fallbacksubdir}/${FRAMEWORK_DIR_NAME}" \
"${owd}/${REFERENCE_DEPENDENCIES_DIR}/${FRAMEWORK_DIR_NAME}" \
"${owd}/${REFERENCE_ADDICTIONS_DIR}/${FRAMEWORK_DIR_NAME}"`
      if [ ! -z "$sdk" ]
      then
         escaped="`escaped_spaces "${owd}/${REFERENCE_DEPENDENCIES_DIR}${mappedsubdir}/${FRAMEWORK_DIR_NAME}"'-$(EFFECTIVE_PLATFORM_NAME)'`"
         path="${escaped} ${path}" # prepend
      fi
      if [ -z "${inherited}" ]
      then
         dependencies_framework_search_path="${path}"
      else
         dependencies_framework_search_path="${path} ${inherited}"
      fi

      if [ ! -z "${public_headers}" ]
      then
         arguments="${arguments} PUBLIC_HEADERS_FOLDER_PATH='${public_headers}'"
      fi
      if [ ! -z "${private_headers}" ]
      then
         arguments="${arguments} PRIVATE_HEADERS_FOLDER_PATH='${private_headers}'"
      fi

      local oldpath
      local rval

      oldpath="${PATH}"
      PATH="${binpath}:${BUILDPATH}"

      log_fluff "PATH temporarily set to $PATH"

      # if it doesn't install, probably SKIP_INSTALL is set
      cmdline="\"${XCODEBUILD}\" \"${command}\" ${arguments} \
ARCHS='${ARCHS:-\${ARCHS_STANDARD_32_64_BIT}}' \
DSTROOT='${owd}/${BUILD_DEPENDENCIES_DIR}' \
SYMROOT='${owd}/${builddir}/' \
OBJROOT='${owd}/${builddir}/obj' \
DEPENDENCIES_DIR='${owd}/${REFERENCE_DEPENDENCIES_DIR}${suffixsubdir}' \
ADDICTIONS_DIR='${owd}/${REFERENCE_ADDICTIONS_DIR}' \
ONLY_ACTIVE_ARCH=${ONLY_ACTIVE_ARCH:-NO} \
${skip_install} \
${other_cflags} \
${other_cxxflags} \
${other_ldflags} \
${XCODEBUILD_FLAGS} \
HEADER_SEARCH_PATHS='${dependencies_header_search_path}' \
LIBRARY_SEARCH_PATHS='${dependencies_lib_search_path}' \
FRAMEWORK_SEARCH_PATHS='${dependencies_framework_search_path}'"

      logging_redirect_eval_exekutor "${logfile}" "${cmdline}"
      rval=$?

      PATH="${oldpath}"
      [ $rval -ne 0 ] && build_fail "${logfile}" "${TOOLNAME}"
      set +f

   exekutor cd "${owd}"
}


build_xcodebuild()
{
   log_entry "build_xcodebuild" "$@"

   local project="$1"
   local builddir="$4"
   local name="$5"

   local scheme
   local schemes

   schemes=`read_build_setting "${name}" "xcode_schemes"`

   IFS="
"
   for scheme in $schemes
   do
      IFS="${DEFAULT_IFS}"
      log_fluff "Building scheme \"${scheme}\" of \"${project}\" ..."
      _build_xcodebuild "$@" "${scheme}" ""
   done
   IFS="${DEFAULT_IFS}"

   local target
   local targets

   targets=`read_build_setting "${name}" "xcode_targets"`

   IFS="
"
   for target in $targets
   do
      IFS="${DEFAULT_IFS}"
      log_fluff "Building target \"${target}\" of \"${project}\" ..."
      _build_xcodebuild "$@" "" "${target}"
   done
   IFS="${DEFAULT_IFS}"

   if [ -z "${targets}" -a -z "${schemes}" ]
   then
      log_fluff "Building project \"${project}\" ..."
      _build_xcodebuild "$@"
   fi
}


test_xcodebuild()
{
   log_entry "test_xcodebuild" "$@"

   [ -z "${MULLE_BOOTSTRAP_XCODE_SH}" ] && . mulle-bootstrap-xcode.sh

   local configuration="$1"
   local srcdir="$2"
   local builddir="$3"
   local name="$4"

   local projectfile
   local projectdir

   local projectname

    # always pass project directly
   projectfile=`read_build_setting "${name}" "xcode_project"`
   if [ ! -z "${projectfile}" ]
   then
      projectfile="${srcdir}/${projectfile}"
   fi

   if [ ! -d "${projectfile}" ]
   then
      projectfile="`find_nearest_matching_pattern "${srcdir}" "*.xcodeproj" "${name}.xcodeproj"`"
      if [ -z "${projectfile}" ]
      then
         log_fluff "There is no Xcode project in \"${srcdir}\""
         return 1
      fi
      projectfile="${srcdir}/${projectfile}"
   fi
   projectdir="`dirname -- "${projectfile}"`"

   tools_environment_xcodebuild "${name}" "${projectdir}"

   if [ -z "${XCODEBUILD}" ]
   then
      log_fluff "No xcodebuild found."
      return 1
   fi

   if [ ! -z "${targetname}" ]
   then
      AUXINFO=" Target ${C_MAGENTA}${C_BOLD}${targetname}${C_INFO}"
   fi

   if [ ! -z "${schemename}" ]
   then
      AUXINFO=" Scheme ${C_MAGENTA}${C_BOLD}${schemename}${C_INFO}"
   fi

   TOOLNAME="`read_config_setting "xcodebuild" "xcodebuild"`"
   PROJECTFILE="${projectfile}"
   WASXCODE="YES"

   return 0
}

