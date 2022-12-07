# shellcheck shell=bash
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


make::common::log_delete_all()
{
   sed d
   : # ensure true for pipe
}


make::common::log_grep_warning_error()
{
   #
   # error/warning grepper
   # try to grep and output warnings and errors generated by clang
   # ignore the rest
   #
   (
      local capture
      local line

      capture='NO'

      while IFS=$'\n' read -r line
      do
         case "${line}" in
            make:*|error:*|warning:*|*:[0-9]*:*error:*|*:[0-9]*:*warning:*|*undefined*reference*)
               capture='YES'
            ;;

            \ *|$'\t'*)
            ;;

            *)
               capture='NO'
            ;;
         esac

         if [ "${capture}" = 'NO' ]
         then
            continue
         fi

         printf "%s\n" "${line}"
      done
   )

   : # ensure true for pipe
}


# local _env_flags
# local _passed_keys
make::common::__add_env_flag()
{
   local envkey="$1"
   local value="$2"

   r_shell_indirect_expand "${envkey}"
   if [ "${value}" != "${RVAL}" ]
   then
      r_concat "${_env_flags}" "${envkey}='${value}'"
      _env_flags="${RVAL}"
      r_colon_concat "${_passed_keys}" "${envkey}"
      _passed_keys="${RVAL}"
   fi
}

make::common::r_env_std_flags()
{
   log_entry "make::common::r_env_std_flags" "$@"

   [ $# -eq 7 ] || _internal_fail "API mismatch"

   local c_compiler="$1"
   local cxx_compiler="$2"
   local cppflags="$3"
   local cflags="$4"
   local cxxflags="$5"
   local ldflags="$6"
   local pkgconfigpath="$7"

   local _env_flags

   make::build::r_env_flags
   _env_flags="${RVAL}"

   local _passed_keys

   make::common::__add_env_flag "CC" "${c_compiler}"
   make::common::__add_env_flag "CXX" "${cxx_compiler}"
   make::common::__add_env_flag "CPPFLAGS" "${cppflags}"
   make::common::__add_env_flag "CFLAGS" "${cflags}"
   make::common::__add_env_flag "CXXFLAGS" "${cxxflags}"
   make::common::__add_env_flag "LDFLAGS" "${ldflags}"
   make::common::__add_env_flag "PKG_CONFIG_PATH" "${pkgconfigpath}"

   # always pass at least a trailing :

   r_concat "${_env_flags}" "__MULLE_MAKE_ENV_ARGS='${_passed_keys:-:}'"
}


# local _c_compiler
# local _cxx_compiler
# local _cppflags
# local _cflags
# local _cxxflags
# local _ldflags
# local _pkgconfigpath
make::common::__std_flags()
{
   log_entry "make::common::__std_flags" "$@"

   [ $# -ge 3 ] || _internal_fail "API mismatch"

   local sdk="$1"
   local platform="$2"
   local configuration="$3"
   local addoptflags="$4"  # optional

   _c_compiler=
   _cxx_compiler=

   case "${DEFINITION_PROJECT_LANGUAGE:-c}" in
      'c')
         make::compiler::r_c_dialect_compiler
         _c_compiler="${RVAL}"

         make::compiler::r_cflags_value "${_c_compiler}" "${configuration}" "${addoptflags}"
         _cflags="${RVAL}"

         make::compiler::r_cppflags_value "${_c_compiler}" "${configuration}"
         _cppflags="${RVAL}"
         make::compiler::r_ldflags_value "${_c_compiler}" "${configuration}"
         _ldflags="${RVAL}"
      ;;

      'cxx'|'c++'|'cpp'|'cplusplus')
         make::compiler::r_cxx_compiler
         _cxx_compiler="${RVAL}"

         make::compiler::r_cxxflags_value "${_cxx_compiler}" "${configuration}" "${addoptflags}"
         _cxxflags="${RVAL}"

         make::compiler::r_cppflags_value "${_cxx_compiler}" "${configuration}"
         _cppflags="${RVAL}"
         make::compiler::r_ldflags_value "${_cxx_compiler}" "${configuration}"
         _ldflags="${RVAL}"
      ;;

      'objc'|'obj-c'|'objective-c'|'objectivec')
         fail "Objective-C is a dialect, not a language"
      ;;

      *)
         log_fluff "No compiler chosen for unknown PROJECT_LANGUAGE=\"${DEFINITION_PROJECT_LANGUAGE}\""
      ;;

   esac

   # hackish! changes cflags and friends to possibly add dependency dir ?

   case "${MULLE_UNAME}" in
      darwin)
      ;;

      *)
         local sdkflags

         make::common::r_sdkpath_tool_flags "${sdk}"
         sdkflags="${RVAL}"
         r_concat "${_cppflags}" "${sdkflags}"
         _cppflags="${RVAL}"
         r_concat "${_ldflags}" "${sdkflags}"
         _ldflags="${RVAL}"
      ;;
   esac

   make::common::r_headerpath_preprocessor_flags
   r_concat "${_cppflags}" "${RVAL}"
   _cppflags="${RVAL}"

   make::common::r_librarypath_linker_flags
   r_concat "${_ldflags}" "${RVAL}"
   _ldflags="${RVAL}"

   _pkgconfigpath="${DEFINITION_PKG_CONFIG_PATH}"
   make::common::r_pkg_config_path
   r_colon_concat "${_pkgconfigpath}" "${RVAL}"
   _pkgconfigpath="${RVAL}"

   #
   # basically adds some flags for android based on chosen SDK
   #
   make::sdk::r_cflags "${sdk}" "${platform}"
   r_concat "${_cflags}" "${RVAL}"
   _cflags="${RVAL}"

   log_setting "c_compiler:      ${_c_compiler}"
   log_setting "cxx_compiler:    ${_cxx_compiler}"
   log_setting "cflags:          ${_cflags}"
   log_setting "cppflags:        ${_cppflags}"
   log_setting "cxxflags:        ${_cxxflags}"
   log_setting "ldflags:         ${_ldflags}"
   log_setting "pkgconfigpath:   ${_pkgconfigpath}"
}


# local _absprojectdir
# local _projectdir
make::common::__project_directories()
{
   log_entry "make::common::__project_directories" "$@"

   local projectfile="$1"

   r_dirname "${projectfile}"
   _projectdir="${RVAL}"
   r_simplified_absolutepath "${_projectdir}"
   _absprojectdir="${RVAL}"

   case "${MULLE_UNAME}" in
      mingw*)
         _projectdir="${_absprojectdir}"
      ;;

#      *)
#         make::common::r_projectdir_relative_to_builddir "${absbuilddir}" "${absprojectdir}"
#         projectdir="${RVAL}"
#      ;;
   esac

   log_setting "absprojectdir: ${_absprojectdir}"
   log_setting "projectdir:    ${_projectdir}"
}


make::common::tools_environment()
{
   log_entry "make::common::tools_environment" "$@"

   if [ "${MULLE_FLAG_LOG_VERBOSE}" = 'YES' ]
   then
      make::command::r_verify_binary "tr" "tr" "tr"
      TR="${RVAL}"
      make::command::r_verify_binary "sed" "sed" "sed"
      SED="${RVAL}"
      [ -z "${TR}" ]   && fail "can't locate tr"
      [ -z "${SED}" ]  && fail "can't locate sed"
   else
      TR=tr
      SED=sed
   fi
}


#
# no ninja here
#
make::common::r_platform_make()
{
   log_entry "make::common::r_platform_make" "$@"

   local compilerpath="$1"
   local plugin="$2"

   case "${MULLE_UNAME}" in
      windows)
         RVAL="nmake.exe"
      ;;

      mingw)
         case "${plugin}" in
            'configure')
               RVAL="mingw32-make"
            ;;

            *)
               local name

               r_basename "${compilerpath}"
               name="${RVAL}"
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

      *)
         RVAL="make"
      ;;
   esac
}


# common functions for build tools

make::common::r_use_ninja_instead_of_make()
{
   log_entry "make::common::r_use_ninja_instead_of_make" "$@"

   #
   # Ninja is preferable if installed for cmake but not else
   #
   local extension

   # temporary fix, because MULLE_EXE_EXTENSION was lost during crafting
   # but I don't know why. If MULLE_UNAME is defined MULLE_EXE_EXTENSION
   # should be as well ?
   case "${MULLE_UNAME}" in
      windows)
         extension="${extension:-.exe}"
      ;;
   esac

   local ninjaexe
   local ninjaversion
   local flag

   flag="${DEFINITION_USE_NINJA:-YES}"
   case "${flag}" in
      'YES')
         ninjaexe="`command -v ninja${extension}`"
         if [ ! -z "${ninjaexe}" ]
         then
            ninjaversion="`"${ninjaexe}" --version`"
            case "${ninjaversion}" in
               0\.*|1\.[0]*|1\.10\.*)
               # less than 1.11 has problems with cleandead
               # https://github.com/ninja-build/ninja/pull/1996
                  if [ "${DEFINITION_USE_NINJA}" = 'YES' ]
                  then
                     log_warning "Ninja is too old (< 1.11.0) to use"
                  fi
                  RVAL=
                  return 1
               ;;

               *)
                  RVAL="ninja${extension}"
                  return 0
               ;;
            esac
         fi

         if [ "${DEFINITION_USE_NINJA}" = 'YES' ]
         then
            fail "ninja${extension} not found"
         fi
         log_debug "ninja${extension} not in PATH"
      ;;

      'NO')
         log_debug "Not searching for ninja"
      ;;

      *)
         _internal_fail "DEFINITION_USE_NINJA contains garbage \"${DEFINITION_USE_NINJA}\""
      ;;
   esac

   RVAL=
   return 1
}


#
# sets the MAKE environment variable
#
make::common::r_make_for_plugin()
{
   log_entry "make::common::r_make_for_plugin" "$@"

   local plugin="$1"
   local no_ninja="$2"

   #
   # allow environment to override
   # (makes testing easier)
   #
   local make

   make="${DEFINITION_MAKE:-${MAKE}}"
   if [ -z "${make}" ]
   then
      make::compiler::r_compiler
      make::common::r_platform_make "${RVAL}" "${plugin}"
      make="${RVAL}"

      if [ -z "${no_ninja}" ]
      then
         if make::common::r_use_ninja_instead_of_make
         then
            make="${RVAL}"
         fi
      fi
   fi

   make::command::r_verify_binary "${make}" "make" "make"
}


#
# the shell escape will protect '$' as '\$'
# but that's not how make needs it. So we unprotect
# and then protect $$ as needed. So make can't mangle
# it.
#
make::common::r_escaped_make_string()
{
   log_entry "make::common::r_escaped_make_string" "$@"

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


make::common::r_makeflags_add()
{
   log_entry "make::common::r_makeflags_add" "$@"

   local makeflags="$1"
   local value="$2"

   if [ -z "${value}" ]
   then
      RVAL="${makeflags}"
      return
   fi

   make::common::r_escaped_make_string "${value}"
   r_escaped_shell_string "${RVAL}"
   r_concat "${makeflags}" "${RVAL}"
}


make::common::r_build_makefile()
{
   log_entry "make::common::r_build_makefile" "$@"

   local make="$1"
   local kitchendir="$2"

   local make_verbose_flags
   local cores

   cores="${OPTION_CORES}"

   case "${make}" in
      *ninja*)
         RVAL="${kitchendir}/build.ninja"
      ;;

      *make*)
         RVAL="${kitchendir}/Makefile"
      ;;
   esac
}


make::common::r_build_make_flags()
{
   log_entry "make::common::r_build_make_flags" "$@"

   local make="$1"
   local make_flags="$2"

   local make_verbose_flags
   local make_terse_flags
   local cores

   cores="${OPTION_CORES}"

   case "${make}" in
      *ninja*)
         make_verbose_flags="-v"
         if [ ! -z "${OPTION_LOAD}" ]
         then
            make::common::r_makeflags_add "${make_flags}" "-l"
            make::common::r_makeflags_add "${RVAL}" "${OPTION_LOAD}"
            make_flags="${RVAL}"
         fi
      ;;

      *nmake*)
         make_verbose_flags="VERBOSE=1"
         make_terse_flags="/C"
      ;;

      *make*)
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
   if [ "${MULLE_FLAG_LOG_TERSE}" = 'YES' ]
   then
      make::common::r_makeflags_add "${make_flags}" "${make_terse_flags}"
      make_flags="${RVAL}"
   else
      make::common::r_makeflags_add "${make_flags}" "${make_verbose_flags}"
      make_flags="${RVAL}"
   fi

   case "${make}" in
      *nmake*)
         if [ "${cores}" == 1 ]
         then
            make::common::r_makeflags_add "${make_flags}" # "/Y" # guess
            make_flags="${RVAL}"
         fi
      ;;

      *)
         if [ ! -z "${cores}" ]
         then
            make::common::r_makeflags_add "${make_flags}" "-j"
            make::common::r_makeflags_add "${RVAL}" "${cores}"
            make_flags="${RVAL}"
         fi
      ;;
   esac
   RVAL="${make_flags}"
}


#
# input:  filepaths, separated by ':'
# sep:    separator to use for output
# escape: YES: single quote escape each file QUOTE: escape and put in quotes
# prefix: prefix to placwe in front of fiile
#
make::common::r_translated_path()
{
   log_entry "make::common::r_translated_path" "$@"

   local input="$1"
   local sep="${2:-:}"
   local escape="$3"    # esa
   local prefix="$4"

   if [ -z "${input}" ]
   then
      RVAL=
      return 0
   fi
   
   local translatepath

   # on mingw we always expect cmake.exe
   # on wsl, we gotta check which it is
   if [ "${MULLE_UNAME}" = "mingw" ]
   then
      translatepath="cygpath"
   else
      case "${CMAKE}" in
         *.exe)
            include "platform::wsl"

            translatepath="platform::wsl::wslpath"
         ;;
      esac
   fi


   local value
   local filepath

   .foreachpath filepath in ${input}
   .do
      # wslpath complains if path is not there, stupid
      if [ ! -z "${translatepath}" ]
      then
         filepath="`${translatepath} -w "${filepath}"`" || exit 1
         [ -z "${filepath}" ] && _internal_fail "translated filepath \"${filepath}\" is returned empty by \"${translatepath}\""
      fi

      case "${escape}" in
         NO|"")
            r_concat "${value}" "${prefix}${filepath}" "${sep}"
         ;;

         YES)
            r_escaped_shell_string "${filepath}"
            r_concat "${value}" "${prefix}${RVAL}" "${sep}"
         ;;

         QUOTE)
            r_escaped_shell_string "${filepath}"
            r_concat "${value}" "${prefix}'${RVAL}'" "${sep}"
         ;;

         *)
            _internal_fail "invalid escape mode"
         ;;
      esac
      value="${RVAL}"
   .done

   [ -z "${value}" ] && _internal_fail "no filepath in \"${input}\""

   RVAL="${value}"
}

#
# preprocessor flags are added to cflags. cflags will be passed via environment
# or as CMAKE_C_FLAGS. So there will be a single quote around everything eventually
#
make::common::r_headerpath_preprocessor_flags()
{
   log_entry "make::common::r_headerpath_preprocessor_flags" "$@"

   local sep="${1:- }"

   local headersearchpaths
   local frameworksearchpaths

   local compiler

   make::compiler::r_compiler
   compiler="${RVAL%.*}"

   if [ -z "${compiler}" ]
   then
      case "${MULLE_UNAME}" in
         darwin|linux|freebsd)
            compiler=gcc
         ;;

         windows)
            compiler="cl"
      esac
   fi

   case "${compiler}" in
      *cl)
         make::common::r_translated_path "${DEFINITION_INCLUDE_PATH}" "${sep}" "YES" "-external:I "
         headersearchpaths="${RVAL}"
      ;;

      *clang|*gcc)
         make::common::r_translated_path "${DEFINITION_INCLUDE_PATH}" "${sep}" "YES" "-isystem "
         headersearchpaths="${RVAL}"
      ;;

      *)
         # assume most compilers can't do -isystem
         make::common::r_translated_path "${DEFINITION_INCLUDE_PATH}" "${sep}" "YES" "-${MULLE_MAKE_ISYSTEM_FLAG:-I}"
         headersearchpaths="${RVAL}"
      ;;
   esac

   case "${MULLE_UNAME}" in
      darwin)
         make::common::r_translated_path "${DEFINITION_FRAMEWORKS_PATH}" "${sep}" "YES" "-F"
         frameworksearchpaths="${RVAL}"
      ;;
   esac

   log_setting "headersearchpaths:    ${headersearchpaths}"
   log_setting "frameworksearchpaths: ${frameworksearchpaths}"

   r_concat "${headersearchpaths}" "${frameworksearchpaths}"
}


make::common::r_librarypath_linker_flags()
{
   log_entry "make::common::r_librarypath_linker_flags" "$@"

   local sep="${1:- }"

   local librarysearchpaths
   local frameworksearchpaths

   case "${MULLE_UNAME}" in
      windows)
         case "${LD:-ld.exe}" in 
            *.exe)
               make::common::r_translated_path "${DEFINITION_LIB_PATH}" "${sep}" "YES" "-LIBPATH:"
               librarysearchpaths="${RVAL}"
            ;;

            *)
               make::common::r_translated_path "${DEFINITION_LIB_PATH}" "${sep}" "YES" "-L"
               librarysearchpaths="${RVAL}"
            ;;
         esac
      ;;

      *)
         make::common::r_translated_path "${DEFINITION_LIB_PATH}" "${sep}" "YES" "-L"
         librarysearchpaths="${RVAL}"
      ;;
   esac

   case "${MULLE_UNAME}" in
      darwin)
         make::common::r_translated_path "${DEFINITION_FRAMEWORKS_PATH}" "${sep}" "YES" "-F"
         frameworksearchpaths="${RVAL}"
      ;;
   esac

   log_setting "librarysearchpaths:   ${librarysearchpaths}"
   log_setting "frameworksearchpaths: ${frameworksearchpaths}"

   r_concat "${librarysearchpaths}" "${frameworksearchpaths}"
}


# return value is already quoted
make::common::r_sdkpath_tool_flags()
{
   log_entry "make::common::r_sdkpath_tool_flags" "$@"

   local sdk="$1"

   local sdkpath

   make::compiler::r_get_sdkpath "${sdk}"
   sdkpath="${RVAL}"

   if [ ! -z "${sdkpath}" ]
   then
      make::common::r_translated_path "${sdkpath}"
      r_escaped_shell_string "${RVAL}"
      RVAL="-isysroot '${RVAL}'"
      return 0
   fi

   return 1
}


make::common::r_pkg_config_path()
{
   log_entry "make::common::r_pkg_config_path" "$@"

   local sep="${1:- }"

   local pkg_config_path

   RVAL=""
   if [ ! -z "${DEFINITION_LIB_PATH}" ]
   then
      make::common::r_translated_path "${DEFINITION_LIB_PATH}/pkgconfig" "${sep}" "YES" ""
      pkg_config_path="${RVAL}"

      log_setting "PKG_CONFIG_PATH:   ${pkg_config_path}"
   fi
}


make::common::r_maketarget()
{
   log_entry "make::common::r_maketarget" "$@"

   local cmd="$1"
   local definitions="$2"

   RVAL=
   .foreachline target in $definitions
   .do
      r_concat "${RVAL}" "'${target}'"
   .done

   case "${cmd}" in
      build|project)
         RVAL="${RVAL:-all}"
      ;;

      install)
         [ -z "${dstdir}" ] && _internal_fail "dstdir is empty"
         RVAL="install"
      ;;

      *)
         r_concat "${RVAL}" "'${cmd}'"
         RVAL="${RVAL}"
      ;;
   esac
}



make::common::_add_path_tool_cppflags()
{
   log_entry "__add_path_tool_flags" "$@"

   _add_sdk_path_tool_flags "$@"
   _add_header_and_library_path_tool_flags
}


make::common::build_fail()
{
   log_entry "make::common::build_fail" "$@"

   local logfile="$1"
   local command="$2"
   local rval="$3"
   local greplog="${4:-YES}"

   if [ "${greplog}" = 'YES' ] && [ -f "${logfile}" ]
   then
      printf "${C_RED}"
      egrep -B1 -A5 -w "[Ee]rror|FAILED:" "${logfile}" >&2
      printf "${C_RESET}"

      if [ "$MULLE_TRACE" != "1848" ]
      then
         # stupid bozo hack
         r_dirname "${logfile}" # remove file
         r_dirname "${RVAL}"    # remove .logs
         r_basename "${RVAL}"    # get project name
         # even worse bozo hack
         case "${RVAL}" in
            Release|Debug|Test)
               RVAL=""
            ;;
         esac

         if [ ! -z "${MULLE_VIRTUAL_ROOT}" ]
         then
            local testprefix

            if [ ! -z "${MULLE_TEST}" ]
            then
               testprefix="test"
            fi

            _log_info "See log with ${C_RESET_BOLD}mulle-sde ${testprefix}log ${RVAL} \
${C_INFO}(${logfile#"${MULLE_USER_PWD}/"})"
         fi
      fi
   fi

   case "$rval" in 
      127)
         if [ -z "${MULLE_VIRTUAL_ROOT}" ]
         then
            fail "${C_RESET_BOLD}${command}${C_ERROR} is apparently not in PATH ($PATH)"
         fi

         if [ -z `mudo which "${command}"` ]
         then
            fail "${C_RESET_BOLD}${command}${C_ERROR} is not installed in PATH ($PATH)"
         fi

         fail "${C_RESET_BOLD}${command}${C_ERROR} is not available.
${C_INFO}You may want to add it with
${C_RESET_BOLD}   mulle-sde tool --global add --optional ${command}"
      ;;

      *)
         fail "${C_RESET_BOLD}${command}${C_ERROR} failed with $rval"
      ;;
   esac
}


make::common::r_build_log_name()
{
   log_entry "make::common::r_build_log_name" "$@"

   local logsdir=$1
   local tool="$2"

   [ -z "${logsdir}" ] && _internal_fail "logsdir missing"
   [ -z "${tool}" ]    && _internal_fail "tool missing"

   r_absolutepath "${logsdir}"

   local countfile

   countfile="${logsdir}/.count"

   local count
   local logfile 
   
   count="`cat "${countfile}" 2> /dev/null`"
   count=${count:-0}

   while :
   do
      # if count exceeds 9 we get a sorting problem
      printf -v logfile "%s/%02d.%s.log" "${logsdir}" ${count} "${tool}"
      count=$(( $count + 1 ))

      if [ ! -f "${logfile}" ]
      then
         redirect_exekutor "${countfile}" printf "%s\n" "${count}"
         exekutor touch "${logfile}"
         RVAL="${logfile}"
         return
      fi
   done
}


make::common::add_path_if_exists()
{
   local line="$1"
   local filepath="$2"

   if [ -e "${filepath}" ]
   then
      r_colon_concat "${line}" "${filepath}"
      line="${RVAL}"
   fi
   printf "%s\n" "${line}"
}


make::common::r_safe_tty()
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
make::common::r_find_nearest_matching_pattern()
{
   log_entry "make::common::r_find_nearest_matching_pattern" "$@"

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

   r_basename "${expectation}"
   match2="${RVAL}"

   #
   # don't go too deep in search
   # error redirection on find to squelch broken symbolic links like
   # find: ‘/home/src/srcM/mulle-cloud/mnt/Assets’: Datei oder Verzeichnis nicht gefunden
   #
   .foreachline i in `rexekutor find -L "${directory}" -maxdepth 2 -name "${pattern}" -print 2> /dev/null`
   .do
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

      r_path_depth "$i"
      new_depth="${RVAL}"

      if [ "${new_depth}" -lt "${depth}" ]
      then
         found="$i"
         depth="${new_depth}"
      fi
   .done

   if [ ! -z "${found}" ]
   then
      RVAL="${found#./}"
      log_debug "\"${RVAL}\" found as nearest match"
      return 0
   fi

   RVAL=""
   return 1
}


make::common::r_projectdir_relative_to_builddir()
{
   log_entry "make::common::r_projectdir_relative_to_builddir" "$@"

   local kitchendir="$1"
   local projectdir="$2"

   r_relative_path_between "${projectdir}" "${kitchendir}"
}

#
#
# build_unix_flags()
# {
#    log_entry "make::common::build_unix_flags" "$@"
#
#    _build_flags "$@"
# }


make::common::initialize()
{
   include "string"
   include "path"
}

make::common::initialize

:
