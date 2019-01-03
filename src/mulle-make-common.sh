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

   local defaultname="${1:-make}"
   local noninja="$2"

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
            if [ ! -z "`command -v ninja`" ]
            then
               RVAL="ninja"
               return
            fi

            if [ "${OPTION_NINJA}" = 'YES' ]
            then
               fail "ninja not found"
            fi
         ;;
      esac
   fi

   toolname="${OPTION_MAKE:-${defaultname:-make}}"
   RVAL="${toolname}"

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

   tools_environment_common

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

}


#
# modifies quasi-global
#
# cflags
# cppflags
# cxxflags
# ldflags
#
__add_path_tool_flags()
{
   local sdkpath

   r_compiler_sdk_parameter "${sdk}"

   sdkpath="${RVAL}"
   if [ ! -z "${sdkpath}" ]
   then
      sdkpath="`"${SED}" -e 's/ /\\ /g' <<< "${sdkpath}" `"
      r_concat "-isysroot ${sdkpath}" "${cppflags}"
      cppflags="${RVAL}"
      r_concat "-isysroot ${sdkpath}" "${ldflags}"
      ldflags="${RVAL}"
   fi

   local headersearchpaths

   case "${OPTION_CC}" in
      *clang*|*gcc)
         r_convert_path_to_flag "${OPTION_INCLUDE_PATH}" "-isystem " "'"
         headersearchpaths="${RVAL}"
      ;;

      *)
         r_convert_path_to_flag "${OPTION_INCLUDE_PATH}" "-I" "'"
         headersearchpaths="${RVAL}"
      ;;
   esac

   r_concat "${cppflags}" "${headersearchpaths}"
   cppflags="${RVAL}"

   local librarysearchpaths

   r_convert_path_to_flag "${OPTION_LIB_PATH}" "-L" "'"
   librarysearchpaths="${RVAL}"
   r_concat "${ldflags}" "${librarysearchpaths}"
   ldflags="${RVAL}"

   case "${MULLE_UNAME}" in
      darwin)
         local frameworksearchpaths

         r_convert_path_to_flag "${OPTION_FRAMEWORKS_PATH}" "-F" "'"
         frameworksearchpaths="${RVAL}"
         r_concat "${ldflags}" "${frameworksearchpaths}"
         ldflags="${RVAL}"
      ;;
   esac
}


build_fail()
{
   log_entry "build_fail" "$@"

   if [ -f "$1" ]
   then
      printf "${C_RED}"
      egrep -B1 -A5 -w "[Ee]rror|FAILED:" "$1" >&2
      printf "${C_RESET}"

      if [ "$MULLE_TRACE" != "1848" ]
      then
         log_info "Check the build log: ${C_RESET_BOLD}${1#${MULLE_USER_PWD}/}${C_INFO}"
      fi
   fi
   fail "$2 failed"
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
      redirect_exekutor "${logsdir}/.count" echo "$count"
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
      echo "${line}"
   fi
}


safe_tty()
{
   local ttyname

   ttyname="`tty`"
   case "${ttyname}" in
      *\ *) # not a tty or so
         echo "/dev/stderr"
      ;;

      *)
         echo "${ttyname}"
      ;;
   esac
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
   IFS="
"
   for i in `find -L "${directory}" -maxdepth 2 -name "${pattern}" -print`
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

   local builddir="$1"
   local projectdir="$2"

   r_relative_path_between "${projectdir}" "${builddir}"
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
