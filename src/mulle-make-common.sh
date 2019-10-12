#! /usr/bin/env bash
#
#   Copyright (c) 2015-2017 Nat! - Mulle kybernetiK
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
MULLE_MAKE_COMMON_SH="included"


#
# The configure plugin can't use nmake on mingw it must use mingw32-make
# (still called mingw32-make on 64 bit)
# The cmake plugin will use nmake though
#
mingw_bitness()
{
   uname | sed -e 's/MINGW\([0-9]*\)_.*/\1/'
}


r_platform_make()
{
   log_entry "r_platform_make" "$@"

   local compilerpath="$1"
   local plugin="$2"

   local name

   r_fast_basename "${compilerpath}"
   name="${RVAL}"

   RVAL="make"
   case "${MULLE_UNAME}" in
      mingw)
         case "${plugin}" in
            'configure')
               RVAL="mingw32-make"
            ;;

            *)
               case "${name%.*}" in
                  ""|cl|clang-cl|mulle-clang-cl)
                     RVAL="nmake"
                  ;;

                  *)
                     RVAL="mingw32-make"
                  ;;
               esac
            ;;
         esac
      ;;
   esac
}


# common functions for build tools

r_find_make()
{
   log_entry "r_find_make" "$@"

   local defaultname="$1"
   local noninja="$2"

   # temporary fix, because MULLE_EXE_EXTENSION was lost during crafting
   # but I don't know why. If MULLE_UNAME is defined MULLE_EXE_EXTENSION 
   # should be as well ?
   
   case "${MULLE_UNAME}" in 
      windows)
         MULLE_EXE_EXTENSION="${MULLE_EXE_EXTENSION:-.exe}"
      ;;
   esac

   defaultname="${defaultname:-make${MULLE_EXE_EXTENSION}}"

   local toolname

   if [ -z "${noninja}"  ]
   then
      #
      # Ninja is preferable if installed for cmake but not else
      #
      case "${OPTION_NINJA}" in
         "")
            internal_fail "OPTION_NINJA must not be empty"
         ;;

         'YES'|"DEFAULT")
            if [ ! -z "`command -v ninja${MULLE_EXE_EXTENSION}`" ]
            then
               RVAL="ninja${MULLE_EXE_EXTENSION}"
               return
            fi

            if [ "${OPTION_NINJA}" = 'YES' ]
            then
               fail "ninja${MULLE_EXE_EXTENSION} not found"
            fi
            log_debug "ninja${MULLE_EXE_EXTENSION} not in PATH"
         ;;

         'NO')
            log_debug "Not searching for ninja"
         ;;

         *)
            internal_fail "OPTION_NINJA contains garbage \"${OPTION_NINJA}\""
         ;;
      esac
   fi

   toolname="${OPTION_MAKE:-${defaultname:-make}}"
   RVAL="${toolname}${MULLE_EXE_EXTENSION}"

   if [ "${MULLE_FLAG_LOG_VERBOSE}" = 'YES' ]
   then
      r_verify_binary "${toolname}" "make" "${defaultname}"
   fi
}


tools_environment_common()
{
   log_entry "tools_environment_common" "$@"

   # no problem if those are empty
   if [ -z "${CC}" ]
   then
      CC="${OPTION_CC}"
   fi

   if [ -z "${CXX}" ]
   then
      CXX="${OPTION_CXX}"
   fi

   if [ "${MULLE_FLAG_LOG_VERBOSE}" = 'YES' ]
   then
      r_verify_binary "tr" "tr" "tr"
      TR="${RVAL}"
      r_verify_binary "sed" "sed" "sed"
      SED="${RVAL}"
      [ -z "${TR}" ]   && fail "can't locate tr"
      [ -z "${SED}" ]  && fail "can't locate sed"
   else
      TR=tr
      SED=sed
   fi
}


tools_environment_make()
{
   log_entry "tools_environment_make" "$@"

   local noninja="$1"
   local plugin="$2"

   #
   # allow environment to override
   # (makes testing easier)
   #
   if [ -z "${MAKE}" ]
   then
      local ourmake

      r_platform_make "${OPTION_CC}" "${plugin}"
      ourmake="${RVAL}"

      r_find_make "${ourmake}" "${noninja}"
      MAKE="${RVAL}"

      [ -z "${MAKE}" ] && fail "can't locate make (named \"${ourmake}\" - on this platform)"
   fi

   tools_environment_common
}


#
# the shell escape will protect '$' as '\$'
# but that's not how make needs it. So we unprotect
# and then protect $$ as needed. So make can't mangle
# it.
#
r_escaped_make_string()
{
   local dollar='$'

   RVAL="$*"

   case "${RVAL}" in
      *\$*)
         RVAL="${RVAL//\\${dollar}/${dollar}}"            # unescape \$ -> $
         case "${RVAL}" in
            *\$[a-z0-9A-Z_%\'\#\?\*@{}-]*)
               RVAL="$( sed 's/$\([a-z0-9A-Z_%'"'"'#?*@{}-]\)/\$\\\1/g' <<< "${RVAL}" )"
            ;;
         esac
         RVAL="${RVAL//${dollar}${dollar}/${dollar}\\${dollar}}"  # escape $$ -> $\$
         RVAL="${RVAL//${dollar}/${dollar}${dollar}}"  # escape $ -> $$
      ;;
   esac
}

r_makeflags_add()
{
   local makeflags="$1"
   local value="$2"

   if [ -z "${value}" ]
   then
      RVAL="${makeflags}"
      return
   fi

   r_escaped_shell_string "${value}"
   r_concat "${makeflags}" "${RVAL}"
}


r_build_make_flags()
{
   log_entry "r_build_make_flags" "$@"

   local make="$1"
   local make_flags="$2"
   local kitchendir="$3"

   local make_verbose_flags
   local cores

   cores="${OPTION_CORES}"

   #
   # hackish
   # figure out if we need to run cmake, by looking for cmakefiles and
   # checking if they are newer than the MAKEFILE
   #
   case "${make}" in
      *ninja*)
         makefile="${kitchendir}/build.ninja"
         make_verbose_flags="-v"
         if [ ! -z "${OPTION_LOAD}" ]
         then
            r_makeflags_add "${make_flags}" "-l"
            r_makeflags_add "${RVAL}" "${OPTION_LOAD}"
            make_flags="${RVAL}"
         fi
      ;;

      *make*)
         makefile="${kitchendir}/Makefile"
         make_verbose_flags="VERBOSE=1"

         if [ -z "${cores}" ]
         then
            r_available_core_count
            cores="${RVAL}"
            log_fluff "Estimated available cores for make: ${cores}"
         fi
      ;;
   esac

   #
   # because the logging is done into files (usually), we don't really want
   # non-verbose output usually
   #
   if [ "${MULLE_FLAG_LOG_TERSE}" != 'YES' ]
   then
      r_makeflags_add "${make_flags}" "${make_verbose_flags}"
      make_flags="${RVAL}"
   fi

   if [ ! -z "${cores}" ]
   then
      r_makeflags_add "${make_flags}" "-j"
      r_makeflags_add "${RVAL}" "${cores}"
      make_flags="${RVAL}"
   fi

   RVAL="${make_flags}"
}



r_convert_file_to_cflag()
{
   local path="$1"
   local flag="$2"

   r_escaped_shell_string "${path}"
   r_escaped_make_string "${RVAL}"
   RVAL="${flag}${RVAL}"
}


r_convert_path_to_cflags()
{
   local path="$1"
   local flag="$2"

   local output

   RVAL=""

   IFS=':'
   set -o noglob
   for component in ${path}
   do
      set +o noglob

      r_convert_file_to_cflag "${component}" "${flag}"
      r_concat "${output}" "${RVAL}"
      output="${RVAL}"
   done
   IFS="${DEFAULT_IFS}"
   set +o noglob
}


#
# modifies quasi-global
#
# cppflags
# ldflags
#
# The flags are escaped for processing by make
# i.e. can be placed into CFLAGS="${CFLAGS}"
#
__add_sdk_path_tool_flags()
{
   log_entry "__add_sdk_path_tool_flags" "$@"

   r_compiler_get_sdkpath "${sdk}"

   local sdkpath

   sdkpath="${RVAL}"
   if [ ! -z "${sdkpath}" ]
   then
      r_convert_file_to_cflag "${sdkpath}" "-isysroot "
      result="${RVAL}"
      r_concat "${result}" "${cppflags}"
      cppflags="${RVAL}"

      r_concat "${result}" "${ldflags}"
      ldflags="${RVAL}"
   fi
}


__add_header_and_library_path_tool_flags()
{
   log_entry "__add_header_and_library_path_tool_flags" "$@"

   local headersearchpaths

   case "${OPTION_CC}" in
      *clang*|*gcc)
         r_convert_path_to_cflags "${OPTION_INCLUDE_PATH}" "-isystem "
         headersearchpaths="${RVAL}"
      ;;

      *)
         r_convert_path_to_cflags "${OPTION_INCLUDE_PATH}" "-I"
         headersearchpaths="${RVAL}"
      ;;
   esac

   r_concat "${cppflags}" "${headersearchpaths}"
   cppflags="${RVAL}"

   local librarysearchpaths

   r_convert_path_to_cflags "${OPTION_LIB_PATH}" "-L"
   librarysearchpaths="${RVAL}"
   r_concat "${ldflags}" "${librarysearchpaths}"
   ldflags="${RVAL}"

   case "${MULLE_UNAME}" in
      darwin)
         local frameworksearchpaths

         r_convert_path_to_cflags "${OPTION_FRAMEWORKS_PATH}" "-F"
         frameworksearchpaths="${RVAL}"

         r_concat "${ldflags}" "${frameworksearchpaths}"
         ldflags="${RVAL}"
      ;;
   esac

   if [ "${MULLE_FLAG_LOG_SETTINGS}" = 'YES' ]
   then
      log_trace2 "cflags:        ${cflags}"
      log_trace2 "cxxflags:      ${cxxflags}"
      log_trace2 "cppflags:      ${cppflags}"
      log_trace2 "ldflags:       ${ldflags}"
   fi
}


__add_path_tool_flags()
{
   log_entry "__add_path_tool_flags" "$@"

   __add_sdk_path_tool_flags
   __add_header_and_library_path_tool_flags
}


build_fail()
{
   log_entry "build_fail" "$@"

   local logfile="$1"
   local command="$2"
   local rval="$3"

   if [ -f "${logfile}" ]
   then
      printf "${C_RED}"
      egrep -B1 -A5 -w "[Ee]rror|FAILED:" "${logfile}" >&2
      printf "${C_RESET}"

      if [ "$MULLE_TRACE" != "1848" ]
      then
         log_info "Check the build log: ${C_RESET_BOLD}${logfile#${MULLE_USER_PWD}/}${C_INFO}"
      fi
   fi
   fail "${command} failed with $rval"
}


r_build_log_name()
{
   log_entry "r_build_log_name" "$@"

   local logsdir=$1
   local tool="$2"

   [ -z "${logsdir}" ] && internal_fail "logsdir missing"
   [ -z "${tool}" ]    && internal_fail "tool missing"

   r_absolutepath "${logsdir}"
   r_filepath_concat "${RVAL}" "${tool}"
   logsdir="${RVAL}"

   local count
   local logfile

   count="`cat "${logsdir}/.count" 2> /dev/null`"
   count=${count:-1}

   logfile="${logsdir}.log"

   while :
   do
      if [ ! -f "${logfile}" ]
      then
         RVAL="${logfile}"
         return
      fi

      logfile="${logsdir}.${count}.log"
      count=$(( $count + 1 ))

      mkdir_if_missing "${logsdir}"
      redirect_exekutor "${logsdir}/.count" printf "%s\n" "$count"
   done
}


add_path_if_exists()
{
   local line="$1"
   local path="$2"

   if [ -e "${path}" ]
   then
      colon_concat "${line}" "${path}"
   else
      printf "%s\n" "${line}"
   fi
}


r_safe_tty()
{
   local tty

   TTY="`command -v tty`"
   if [ ! -z "${TTY}" ]
   then
      RVAL="`${TTY}`"
	   case "${RVAL}" in
	      *\ *) # not a tty or so
	         RVAL="/dev/stderr"
	      ;;
	   esac
   else
      RVAL="/dev/stderr"
   fi

   # can happen if sued to another user id
   if [ ! -w "${RVAL}" ]
   then
      log_warning "Can't write to console. Direct output unvailable, see logs."
   	RVAL="/dev/null"
   fi
}

#
# first find a project with matching name, otherwise find
# first nearest project
#
r_find_nearest_matching_pattern()
{
   log_entry "r_find_nearest_matching_pattern" "$@"

   local directory="$1"
   local pattern="$2"
   local expectation="$3"

   if [ ! -d "${directory}" ]
   then
      log_warning "\"${directory}\" not found"
      RVAL=""
      return 1
   fi

   local depth

   found=""
   depth=1000

   #     IFS='\0'

   local match1
   local match2
   local new_depth

   r_fast_basename "${expectation}"
   match2="${RVAL}"

   #
   # don't go too deep in search
   #
   IFS=$'\n'
   for i in `rexekutor find -L "${directory}" -maxdepth 2 -name "${pattern}" -print`
   do
      IFS="${DEFAULT_IFS}"

      if [ "${i}" = "${expectation}" ]
      then
         log_fluff "\"${RVAL}\" found as complete match"
         RVAL="$i"
         return 0
      fi

      match1="${i##*/}"
      if [ "${match1}" = "${match2}" ]
      then
         RVAL="$i"
         log_fluff "\"${RVAL}\" found as matching filename "
         return 0
      fi

      new_depth="`path_depth "$i"`"
      if [ "${new_depth}" -lt "${depth}" ]
      then
         found="$i"
         depth="${new_depth}"
      fi
   done
   IFS="${DEFAULT_IFS}"

   if [ ! -z "${found}" ]
   then
      RVAL="${found#./}"
      log_debug "\"${RVAL}\" found as nearest match"
      return 0
   fi

   RVAL=""
   return 1
}


r_projectdir_relative_to_builddir()
{
   log_entry "r_projectdir_relative_to_builddir" "$@"

   local kitchendir="$1"
   local projectdir="$2"

   r_relative_path_between "${projectdir}" "${kitchendir}"
}



build_unix_flags()
{
   log_entry "build_unix_flags" "$@"

   _build_flags "$@"
}


make_common_initialize()
{
   if [ -z "${MULLE_STRING_SH}" ]
   then
      . "${MULLE_BASHFUNCTIONS_LIBEXEC_DIR}/mulle-string.sh" || return 1
   fi
   if [ -z "${MULLE_PATH_SH}" ]
   then
      . "${MULLE_BASHFUNCTIONS_LIBEXEC_DIR}/mulle-path.sh" || return 1
   fi
}

make_common_initialize

:
