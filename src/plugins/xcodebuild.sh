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
MULLE_MAKE_PLUGIN_XCODEBUILD_SH="included"


find_xcodebuild()
{
   local toolname

   toolname="${OPTION_XCODEBUILD:-${XCODEBUILD:-xcodebuild}}"
   verify_binary "${toolname}" "xcodebuild" "xcodebuild"
}


tools_environment_xcodebuild()
{
   tools_environment_common

   XCODEBUILD="`find_xcodebuild`"
}


#
# use this with +=
#
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


#
# Let's not inherit here
#
convert_path_to_value()
{
   local path="$1"
   local inherit="${2:-NO}"

   local output
   local component

   IFS=":"
   set -o noglob
   for component in ${path}
   do
      output="`concat "${output}" "${component}" `"
   done
   IFS="${DEFAULT_IFS}"
   set +o noglob

   if [ "${inherit}" = "YES" -a ! -z "${inherit}" ]
   then
      output="`concat "${output}" "\$(inherited)" `"
   fi


   printf "%s" "${output}"
}


_build_xcodebuild()
{
   log_entry "_build_xcodebuild" "$@"

   local command="$1"; shift

   local projectfile="$1"; shift
   local configuration="$1"; shift
   local srcdir="$1"; shift
   local dstdir="$1"; shift
   local builddir="$1"; shift
   local logsdir="$1"; shift
   local sdk="$1"; shift

   local schemename="$1"
   local targetname="$2"

   [ ! -z "${configuration}" ] || internal_fail "configuration is empty"
   [ ! -z "${srcdir}" ]        || internal_fail "srcdir is empty"
   [ ! -z "${builddir}" ]      || internal_fail "builddir is empty"
   [ ! -z "${sdk}" ]           || internal_fail "sdk is empty"
   [ ! -z "${projectfile}" ]   || internal_fail "project is empty"

   local projectdir

   projectdir="`dirname -- "${projectfile}" `"

   #
   # xctool needs schemes, these are often autocreated, which xctool cant do
   # xcodebuild can just use a target
   # xctool is by and large useless fluff IMO
   #
   if [ "${TOOLNAME}" = "xctool"  -a -z "${schemename}" ]
   then
      if [ ! -z "${targetname}" ]
      then
         schemename="${targetname}"
         targetname=
      else
         cat <<EOF >&2
Please specify a scheme to compile in ${MAKE_DIR}/${name}/SCHEME for
xctool and be sure that this scheme exists and is shared. Or delete
${HOME}/.mulle-make/xcodebuild and use xcodebuild (preferred).
EOF
         exit 1
      fi
   fi

   # now don't load any settings anymoe
   local action

   case "${command}" in
      build)
         action="build"
         dstdir="" # paranoia
      ;;

      install)
         action="install"
      ;;
   esac

   local arguments

   arguments=""
   if [ ! -z "${projectname}" ]
   then
      arguments="$(concat "${arguments}" "-project '${projectname}'" )"
   fi
   if [ ! -z "${sdk}" ]
   then
      if [ "${sdk}" = "Default" ]
      then
         arguments="$(concat "${arguments}" "-sdk 'macosx'" )"
      else
         arguments="$(concat "${arguments}" "-sdk '${sdk}'" )"
      fi
   fi

   if [ -z "${schemename}" -a -z "${targetname}" ]
   then
      arguments="$(concat "${arguments}" "-alltargets")"
   else
      if [ ! -z "${schemename}" ]
      then
         arguments="$(concat "${arguments}" "-scheme '${schemename}'" )"
      else
         arguments="$(concat "${arguments}" "-target '${targetname}'" )"
      fi
   fi
   if [ ! -z "${configuration}" ]
   then
      arguments="$(concat "${arguments}" "-configuration '${configuration}'" )"
   fi

   # an empty xcconfig is nice, because it acts as a reset for ?
   local xcconfig

   xcconfig="${OPTION_XCODE_XCCONFIG_FILE}"
   if [ ! -z "${xcconfig}" ]
   then
      arguments="$(concat "${arguments}" "-xcconfig '${xcconfig}'" )"
   fi

   local buildsettings
   local user_buildsettings
   local absbuilddir

   # don't expand stuff with variables
   case "${builddir}" in
      ""|*$*)
         absbuilddir="${builddir}"
      ;;

      *)
         absbuilddir="`absolutepath "${builddir}" `"
      ;;
   esac

   buildsettings="ARCHS='${OPTION_XCODE_ARCHS:-\${ARCHS_STANDARD_32_64_BIT}}'"
   buildsettings="`concat "${buildsettings}" "DSTROOT='${dstdir:-${absbuilddir}}'" `"
   buildsettings="`concat "${buildsettings}" "OBJROOT='${absbuilddir}/obj'" `"
   buildsettings="`concat "${buildsettings}" "SYMROOT='${absbuilddir}/'" `"
   buildsettings="`concat "${buildsettings}" "ONLY_ACTIVE_ARCH='${ONLY_ACTIVE_ARCH:-NO}'" `"

   local env_common

   env_common="`mulle_make_env_flags`"

   local cflags
   local cxxflags
   local ldflags

   if [ ! -z "${OPTION_CFLAGS}" ]
   then
      buildsettings="`concat "${buildsettings}" "CFLAGS='${OPTION_CFLAGS}'" `"
   fi
   if [ ! -z "${OPTION_CXXFLAGS}" ]
   then
      buildsettings="`concat "${buildsettings}" "CXXFLAGS='${OPTION_CXXFLAGS}'" `"
   fi
   if [ ! -z "${OPTION_LDFLAGS}" ]
   then
      buildsettings="`concat "${buildsettings}" "LDFLAGS='${OPTION_LDFLAGS}'" `"
   fi

   if [ ! -z "${OPTION_OTHER_CFLAGS}" ]
   then
      buildsettings="`concat "${buildsettings}" "OTHER_CFLAGS='${OPTION_OTHER_CFLAGS}'" `"
   fi
   if [ ! -z "${OPTION_OTHER_CXXFLAGS}" ]
   then
      buildsettings="`concat "${buildsettings}" "OTHER_CXXFLAGS='${OPTION_OTHER_CXXFLAGS}'" `"
   fi
   if [ ! -z "${OPTION_OTHER_LDFLAGS}" ]
   then
      buildsettings="`concat "${buildsettings}" "OTHER_LDFLAGS='${OPTION_OTHER_LDFLAGS}'" `"
   fi

   if [ ! -z "${OPTION_PREFIX}" ]
   then
      buildsettings="`concat "${buildsettings}" "DYLIB_INSTALL_NAME_BASE='${OPTION_PREFIX}'" `"
   fi

   if [ "${OPTION_XCODE_HAS_PROPER_SKIP_INSTALL:-NO}" = "NO" ]
   then
      buildsettings="`concat "${buildsettings}" "SKIP_INSTALL=NO" `"
   fi

   #
   # create HEADER_SEARCH_PATHS LIBRARY_SEARCH_PATHS FRAMEWORK_SEARCH_PATHS
   # we don't inherit
   #
   local value

   value="`convert_path_to_value "${OPTION_INCLUDE_PATH}"`"
   if [ ! -z "${value}" ]
   then
      buildsettings="`concat "${buildsettings}" "HEADER_SEARCH_PATHS='${value}'" `"
   fi

   value="`convert_path_to_value "${OPTION_LIB_PATH}"`"
   if [ ! -z "${value}" ]
   then
      buildsettings="`concat "${buildsettings}" "LIBRARY_SEARCH_PATHS='${value}'" `"
   fi

   value="`convert_path_to_value "${OPTION_FRAMEWORKS_PATH}"`"
   if [ ! -z "${value}" ]
   then
      buildsettings="`concat "${buildsettings}" "FRAMEWORK_SEARCH_PATHS='${value}'" `"
   fi

   user_buildsettings="`emit_userdefined_definitions`"
   if [ ! -z "${user_buildsettings}" ]
   then
      buildsettings="`concat "${buildsettings}" "${user_buildsettings}" `"
   fi

   local logfile

   mkdir_if_missing "${logsdir}"
   logfile="`build_log_name "${logsdir}" "${TOOLNAME}" "${srcdir}" \
                            "${configuration}" "${targetname}" "${schemename}" \
                            "${sdk}" `" || exit 1

   if [ "${MULLE_FLAG_LOG_VERBOSE}" = "YES" ]
   then
      logfile="`safe_tty`"
   fi
   if [ "$MULLE_FLAG_EXEKUTOR_DRY_RUN" = "YES" ]
   then
      logfile="/dev/null"
   fi
   log_verbose "Build log will be in: ${C_RESET_BOLD}${logfile}${C_VERBOSE}"


   (
      set -f  # prevent bash from expanding glob

      exekutor cd "${projectdir}" || exit 1

      # DONT READ CONFIG SETTING IN THIS INDENT

      [ -z "${BUILDPATH}" ] && internal_fail "BUILDPATH not set"
      PATH="${BUILDPATH}"
      log_fluff "PATH temporarily set to $PATH"
      if [ "${MULLE_FLAG_LOG_ENVIRONMENT}" = "YES" ]
      then
         env | sort >&2
      fi


      # if it doesn't install, probably SKIP_INSTALL is set
      if ! logging_redirect_eval_exekutor "${logfile}" \
                                          "${env_common}" \
            "'${XCODEBUILD}'" ${action} "${arguments}" "${buildsettings}"
      then
         build_fail "${logfile}" "${TOOLNAME}"
      fi
   ) || exit 1
}


build_xcodebuild()
{
   log_entry "build_xcodebuild" "$@"

   local project="$2"

   local scheme
   local schemes

   schemes="${OPTION_SCHEMES}"
   IFS="
"
   set -o noglob
   for scheme in $schemes
   do
      IFS="${DEFAULT_IFS}"
      set +o noglob

      log_fluff "Building scheme \"${scheme}\" of \"${project}\" ..."
      _build_xcodebuild "$@" "${scheme}" ""
   done
   IFS="${DEFAULT_IFS}"
   set +o noglob

   local target
   local targets

   targets="${OPTION_TARGETS}"

   IFS="
"
   set -o noglob
   for target in $targets
   do
      IFS="${DEFAULT_IFS}"
      set +o noglob

      log_fluff "Building target \"${target}\" of \"${project}\" ..."
      _build_xcodebuild "$@" "" "${target}"
   done
   IFS="${DEFAULT_IFS}"
   set +o noglob

   if [ -z "${targets}" -a -z "${schemes}" ]
   then
      log_fluff "Building project \"${project}\" ..."
      _build_xcodebuild "$@"
   fi
}


test_xcodebuild()
{
   log_entry "test_xcodebuild" "$@"

   local configuration="$1"
   local srcdir="$2"

   local projectfile
   local projectdir

   local projectname

    # always pass project directly
   projectfile="${OPTION_PROJECT_FILE}"
   if [ ! -z "${projectfile}" ]
   then
      projectfile="${srcdir}/${projectfile}"
   fi

   if [ ! -d "${projectfile}" ]
   then
      projectfile="`find_nearest_matching_pattern "${srcdir}" "*.xcodeproj" "${name}.xcodeproj" `"
      if [ -z "${projectfile}" ]
      then
         log_fluff "There is no Xcode project in \"${srcdir}\""
         return 1
      fi
   fi

   projectdir="`dirname -- "${projectfile}" `"
   tools_environment_xcodebuild "${projectdir}"

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

   TOOLNAME="`basename -- "${XCODEBUILD}" `"
   PROJECTFILE="${projectfile}"
   WASXCODE="YES"

   return 0
}



xcodebuild_plugin_initialize()
{
   log_entry "xcodebuild_plugin_initialize"

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

xcodebuild_plugin_initialize

:

