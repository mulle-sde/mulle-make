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


platform_make()
{
   local compilerpath="$1"

   local name

   name="`basename -- "${compilerpath}"`"

   case "${UNAME}" in
      mingw)
         case "${name%.*}" in
            ""|cl|clang-cl|mulle-clang-cl)
               echo "nmake"
            ;;

            *)
               echo "mingw32-make"
            ;;
         esac
      ;;

      *)
         echo "make"
      ;;
   esac
}


# common functions for build tools

find_make()
{
   local defaultname="${1:-make}"
   local noninja="$2"

   local toolname

   if [ -z "${noninja}"  ]
   then
      #
      # Ninja is preferable if installed for cmake but not else
      #
      case "${OPTION_NINJA}" in
         "YES"|"DEFAULT")
            if [ ! -z "`command -v ninja`" ]
            then
               echo "ninja"
               return
            fi

            if [ "${OPTION_NINJA}" = "YES" ]
            then
               fail "ninja not found"
            fi
         ;;
      esac
   fi

   toolname="${OPTION_MAKE:-${MAKE:-make}}"
   verify_binary "${toolname}" "make" "${defaultname}"
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

   TR="`verify_binary "tr" "tr" "tr"`"
   SED="`verify_binary "sed" "sed" "sed"`"

   [ -z "${TR}" ]   && fail "can't locate tr"
   [ -z "${SED}" ]  && fail "can't locate sed"
}


tools_environment_make()
{
   local noninja="$1"

   tools_environment_common

   #
   # allow environment to override
   # (makes testing easier)
   #
   if [ -z "${MAKE}" ]
   then
      local defaultmake

      defaultmake="`platform_make "${CC}"`"
      MAKE="`find_make "${defaultmake}" "${noninja}"`"
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

   sdkpath="`compiler_sdk_parameter "${sdk}"`"
   sdkpath="`echo "${sdkpath}" | "${SED}" -e 's/ /\\ /g'`"

   if [ ! -z "${sdkpath}" ]
   then
      cppflags="`concat "-isysroot ${sdkpath}" "${cppflags}"`"
      ldflags="`concat "-isysroot ${sdkpath}" "${ldflags}"`"
   fi

   local headersearchpaths

   case "${OPTION_CC}" in
      *clang*|*gcc)
         headersearchpaths="`convert_path_to_flag "${OPTION_INCLUDE_PATH}" "-isystem " "'"`"
      ;;

      *)
         headersearchpaths="`convert_path_to_flag "${OPTION_INCLUDE_PATH}" "-I" "'"`"
      ;;
   esac
   cppflags="`concat "${cppflags}" "${headersearchpaths}"`"

   local librarysearchpaths

   librarysearchpaths="`convert_path_to_flag "${OPTION_LIB_PATH}" "-L" "'"`"
   ldflags="`concat "${ldflags}" "${librarysearchpaths}"`"

   local frameworksearchpaths

   frameworksearchpaths="`convert_path_to_flag "${OPTION_FRAMEWORKS_PATH}" "-F" "'"`"
   ldflags="`concat "${ldflags}" "${frameworksearchpaths}"`"
}


build_fail()
{
   log_entry "build_fail" "$@"

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


guess_project_name()
{
   log_entry "guess_project_name" "$@"

   local directory="$1"

   [  -z "${directory}" ] && internal_fail "empty parameter"
   directory="$(absolutepath "${directory}")"

   while :
   do
      parent="`dirname -- "${directory}"`"
      name="`basename -- "${directory}"`"
      directory="${parent}"

      if [ "${directory}" = "." ]
      then
         echo "${name}"
         return
      fi

      case "${name}" in
         .|..|trunk|branch|branches|src|source|sources)
         ;;

         *)
            echo "${name}"
            return
         ;;
       esac
   done
}


#
# build log will be of form
# <name>--<configuration>-<sdk>.<tool>.log
# It is ensured, that
build_log_name()
{
   log_entry "build_log_name" "$@"

   local logsdir=$1; shift
   local tool="$1"; shift
   local srcdir="$1"; shift

   [ -z "${logsdir}" ] && internal_fail "logsdir missing"
   [ -z "${tool}" ]    && internal_fail "tool missing"
   [ -z "${srcdir}" ]  && internal_fail "srcdir missing"

   local logfile
   local s
   local name

   name="${OPTION_PROJECT_NAME}"
   if [ -z "${name}" ]
   then
      name="$(guess_project_name "${srcdir}")"
   fi

   case "${name}" in
      *-)
         fail "Dependency \"${name}\" ends with -, that won't work here"
      ;;

      *--*)
         fail "Dependency \"${name}\" contains --, that won't work here"
      ;;
   esac

   logfile="${logsdir}/${name}"
   if [ $# -ne 0 ]
   then
      # want to separate with --
      logfile="${logfile}-"
   fi

   while [ $# -gt 0 ]
   do
      s="$1"
      shift

      if [ ! -z "$s" ]
      then
         s="${s//-/_}"
         logfile="${logfile}-${s}"
      fi
   done

   tool="${tool//-/_}"
   absolutepath "${logfile}.${tool}.log"
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
find_nearest_matching_pattern()
{
   log_entry "find_nearest_matching_pattern" "$@"

   local directory="$1"
   local pattern="$2"
   local expectation="$3"

   if [ ! -d "${directory}" ]
   then
      log_warning "\"${directory}\" not found"
      return 1
   fi

   local found

   #
   # allow user to specify directory to use for building
   #
   found="`egrep -s -v '^#"' "${directory}/.mulle-make-dir.${UNAME}" `"
   if [  -z "${found}" ]
   then
      found="`egrep -s -v '^#"' "${directory}/.mulle-make-dir" `"
   fi

   if [ ! -z "${found}" ]
   then
      log_fluff "Use .mulle-make-dir specified directory \"${found}\""
      echo "${found}"
      return
   fi

   local depth

   found=""
   depth=1000

   #     IFS='\0'

   local match1
   local match2
   local new_depth

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
         echo "$i"
         log_fluff "\"${i}\" found as complete match"
         return 0
      fi

      match1=`basename -- "$i"`
      match2=`basename -- "${expectation}"`
      if [ "${match1}" = "${match2}" ]
      then
         echo "$i"
         log_fluff "\"${i}\" found as filename match"
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
      found="`sed 's|^\./||g' <<< "${found}"`"
      log_fluff "\"${found}\" found as nearest match"
      echo "${found}"
      return 0
   fi

   return 1
}


projectdir_relative_to_builddir()
{
   log_entry "projectdir_relative_to_builddir" "$@"

   local builddir="$1"
   local projectdir="$2"

   local directory

   directory="`relative_path_between "${projectdir}" "${builddir}"`"
   case "${UNAME}" in
      mingw)
         echo "${directory}" | "${TR}" '/' '\\'  2> /dev/null
      ;;

      *)
         echo "${directory}"
      ;;
   esac
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
