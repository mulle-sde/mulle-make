# mulle-make bash completion
#
# Context-aware completion for `mulle-make`.
#
# Features:
#   - all top-level commands (visible, hidden and aliases)
#   - subcommands for `definition` and `log`
#   - complete option set for every command/subcommand
#   - option argument completion (files, directories, libraries, configs, ...)
#   - dynamic discovery via `mulle-make -v help` / `<cmd> -h` with caching
#   - static fallbacks when the binary is missing or fails
#
# Source: https://github.com/mulle-nat/mulle-make
# Completion listing: `mulle-make -v help`, `mulle-make <cmd> -h`

# ---- only makes sense in interactive bash --------------------------------
[[ -n ${BASH_VERSION:-} ]] || return
if [[ ${BASH_VERSINFO[0]:-0} -lt 4 ]]; then
   return
fi

# --------------------------------------------------------------------------
# static data (used directly and as fallback for dynamic discovery)
# --------------------------------------------------------------------------

# cache length in seconds; grows in development, costs one extra subprocess call
__mulle_make_TTL="${MULLE_MAKE_COMPLETION_TTL:-10}"

__mulle_make_MAIN_COMMANDS="project build make clean definition install craft list log show libexec-dir library-path uname version"

__mulle_make_MAIN_FLAGS="-f --force -n -s -v -ld -le -lt -lx --args --clear --clear-global-definitions --no-clear --no-clear-global-definitions --version -h --help help"

# complete build option set, compiled from make::build::common and the
# remove/uncommon emit functions in src/mulle-make-build.sh
__mulle_make_BUILD_OPTIONS="-h --help help -D -U --build-dir -c --configuration --debug --release --mulle-test --ninja --no-ninja --include-path -I --library-path -L --lib-path --frameworks-path -F --definition-dir -d --aux-definition-dir --info-dir --makeinfo-dir --prefix --log-dir -j --cores --serial --no-parallel --dynamic --static --standalone --shared --preferred-library-style --library-style --platform --sdk -s --determine-sdk --no-determine-sdk --project-name --name --project-language --language --project-dialect --dialect --phase --path --toolchain --toolchain-tools-root --xcode-config-file --plugins --plugin-preferences --tools --tool-preferences --clean -k --no-clean -K --analyze --no-analyze --allow-script --no-allow-script --allow-build-script --allow-unknown-option --no-allow-unknown-option --ccache --make --no-make --autoconf --no-autoconf --configure --no-configure --no-cmake --xcodebuild --no-xcodebuild --prefer-xcodebuild --rerun-cmake --set-is-plus --underline --show-log-info --syntax-check --verbose-make --target --targets --load -l --append --ifempty --remove"

__mulle_make_DEFINITION_SUBCOMMANDS="cat export get list set show keys unset remove write merge"

__mulle_make_LOG_SUBCOMMANDS="list clean"
__mulle_make_LOG_TOOLS="cat zcat sed grep egrep rg ack tail head less more wc diff xargs"

__mulle_make_DEFINITION_OPTIONS="-h --help --allow-unknown-option --no-allow-unknown-option --definition-dir --aux-definition-dir -D -U"

__mulle_make_DEFINITION_SET_OPTIONS="-h --help -+ --additive --xcode-additive --non-additive --no-xcode-additive --concat --concat0 --append --append0 --ifempty --remove --unset --clobber --set-is-plus"
__mulle_make_DEFINITION_GET_OPTIONS="-h --help --output-key --set-is-plus"
__mulle_make_DEFINITION_LIST_OPTIONS="-h --help --set-is-plus"
__mulle_make_DEFINITION_UNSET_OPTIONS="-h --help --set-is-plus"
__mulle_make_DEFINITION_EXPORT_OPTIONS="-h --help --export-command --prefix"
__mulle_make_DEFINITION_WRITE_OPTIONS="-h --help --append --append0 --ifempty --remove --unset --clobber --set-is-plus"

__mulle_make_LOG_OPTIONS="-h --help -t --tool"

# style / configuration / language / plugin / platform value pools
__mulle_make_LIBRARY_STYLES="dynamic standalone static"
__mulle_make_CONFIGURATIONS="Debug Release Test"
__mulle_make_LANGUAGES="c cpp"
__mulle_make_PLUGINS="cmake meson autoconf configure make script xcodebuild"
__mulle_make_PLATFORMS="Default linux darwin mingw freebsd sunos windows"
__mulle_make_LOG_TOOLS_UNITS="cmake ninja make gcc g++ clang clang++ cc cpp as ld ar ranlib configure autoconf meson xcodebuild"

# known definition keys, compiled from the KNOWN_DEFINITIONS table in
# src/mulle-make-definition.sh (DEFINITION_ prefix stripped)
__mulle_make_DEFINITION_KEYS="BUILD_DIR BUILD_SCRIPT CC CFLAGS CLEAN_BEFORE_BUILD CMAKE CMAKE1 COBJC CONFIGURATION CPPFLAGS CXX CXXFLAGS DETERMINE_SDK FRAMEWORKS_PATH GCC_PREPROCESSOR_DEFINITIONS INCLUDE_PATH LDFLAGS LIB_PATH LIBRARY_STYLE LOG_DIR MAKE MAKETARGET NINJA OBJCFLAGS OTHER_CFLAGS OTHER_CPPFLAGS OTHER_CXXFLAGS OTHER_LDFLAGS OTHER_OBJCFLAGS PLATFORM PLUGIN_PREFERENCES PREFER_XCODEBUILD PREFERRED_LIBRARY_STYLE PREFIX PROJECT_DIALECT PROJECT_FILE PROJECT_LANGUAGE PROJECT_NAME SCHEMES SDK SELECT_CC SELECT_COBJC SELECT_CXX TARGETS TOOLCHAIN TOOLCHAIN_CMAKE TOOLCHAIN_MESON TOOLCHAIN_TOOLS_ROOT MESON_CROSS_FILE USE_NINJA WARNING_CFLAGS AUTOCONF AUTORECONF AUTOCONFFLAGS AUTORECONFFLAGS CMAKE_BUILD_TYPE CMAKE_C_FLAGS CMAKE_CXX_FLAGS CMAKE_C_COMPILER CMAKE_CXX_COMPILER CMAKE_LINKER CMAKE_SHARED_LINKER_FLAGS CMAKE_EXE_LINKER_FLAGS CMAKE_INCLUDE_PATH CMAKE_LIBRARY_PATH CMAKE_FRAMEWORK_PATH CMAKE_INSTALL_PREFIX CMAKEFLAGS CMAKE_GENERATOR CONFIGUREFLAGS MESON MESONFLAGS MESON_BACKEND XCODEBUILD XCODE_XCCONFIG_FILE MULLE_SDK_PATH MULLE_SDK_SUBDIR"

# --------------------------------------------------------------------------
# caching helpers
# --------------------------------------------------------------------------

__mulle_make_epoch()
{
   if [[ -n ${EPOCHSECONDS:-} ]]; then
      printf '%s' "${EPOCHSECONDS}"
   else
      printf '%s' "$(date +%s 2>/dev/null)"
   fi
}


__mulle_make_cache_valid()
{
   local name="$1"
   local now="${2:-0}"

   local ts
   local data

   eval "ts=\"\${__mulle_make_cached_${name}_ts:-}\""
   eval "data=\"\${__mulle_make_cached_${name}:-}\""

   [[ -n "${ts}" && -n "${data}" ]] || return 1
   (( now - ts < __mulle_make_TTL ))
}


__mulle_make_cache_get()
{
   local name="$1"

   eval "printf '%s' \"\${__mulle_make_cached_${name}:-}\""
}


__mulle_make_cache_set()
{
   local name="$1"
   local data="$2"
   local now="${3:-0}"

   eval "__mulle_make_cached_${name}='${data//\'/\'\\\'\'}'"
   eval "__mulle_make_cached_${name}_ts='${now}'"
}


__mulle_make_timeout_prefix()
{
   if command -v timeout >/dev/null 2>&1; then
      printf 'timeout 2 '
   fi
}


__mulle_make_r_merge_words()
{
   local result="$1"
   local word

   for word in $2
   do
      case " ${result} " in
         *" ${word} "*)
         ;;
         *)
            result="${result} ${word}"
         ;;
      esac
   done
   printf '%s' "${result}"
}

# --------------------------------------------------------------------------
# dynamic discovery (cached)
# --------------------------------------------------------------------------

__mulle_make_discover_commands()
{
   local bin
   local timeout

   bin="$(command -v mulle-make 2>/dev/null)" || return 1

   timeout="$(__mulle_make_timeout_prefix)"
   eval "${timeout} \"\${bin}\" -v help 2>&1" \
      | sed -n 's/^   \([A-Za-z0-9-]*\) *:.*/\1/p' \
      | grep -v '^-'
}


__mulle_make_commands()
{
   local now
   local dynamic
   local merged

   now="$(__mulle_make_epoch)"
   if __mulle_make_cache_valid commands "${now}"; then
      __mulle_make_cache_get commands
      return
   fi

   dynamic="$(__mulle_make_discover_commands)"
   if [[ -n "${dynamic}" ]]; then
      merged="$(__mulle_make_r_merge_words "${__mulle_make_MAIN_COMMANDS}" "${dynamic}")"
   else
      merged="${__mulle_make_MAIN_COMMANDS}"
   fi

   __mulle_make_cache_set commands "${merged}" "${now}"
   printf '%s' "${merged}"
}


__mulle_make_discover_subcommands()
{
   local bin="$1"
   local cmd="$2"
   local timeout

   timeout="$(__mulle_make_timeout_prefix)"
   eval "${timeout} \"\${bin}\" \"\${cmd}\" -h 2>&1" \
      | sed -n 's/^   \([A-Za-z0-9-]*\) *:.*/\1/p' \
      | grep -v '^-'
}


__mulle_make_subcommands()
{
   local cmd="$1"
   local cache="subcommands_${cmd}"
   local now
   local bin
   local dynamic
   local merged
   local statics

   case "${cmd}" in
      definition) statics="${__mulle_make_DEFINITION_SUBCOMMANDS}" ;;
      log)        statics="${__mulle_make_LOG_SUBCOMMANDS}" ;;
      *)          statics="" ;;
   esac

   [[ -n "${statics}" ]] || return

   now="$(__mulle_make_epoch)"
   if __mulle_make_cache_valid "${cache}" "${now}"; then
      __mulle_make_cache_get "${cache}"
      return
   fi

   bin="$(command -v mulle-make 2>/dev/null)"
   dynamic="$(__mulle_make_discover_subcommands "${bin}" "${cmd}")"

   if [[ -n "${dynamic}" ]]; then
      merged="$(__mulle_make_r_merge_words "${statics}" "${dynamic}")"
   else
      merged="${statics}"
   fi

   __mulle_make_cache_set "${cache}" "${merged}" "${now}"
   printf '%s' "${merged}"
}


__mulle_make_discover_build_options()
{
   local bin="$1"
   local timeout

   timeout="$(__mulle_make_timeout_prefix)"
   eval "${timeout} \"\${bin}\" -v project -h 2>&1" \
      | sed -n 's/^ *\([+-]\+[A-Za-z0-9-]*\).*/\1/p'
}


__mulle_make_build_options()
{
   local now
   local bin
   local dynamic
   local merged

   now="$(__mulle_make_epoch)"
   if __mulle_make_cache_valid build_options "${now}"; then
      __mulle_make_cache_get build_options
      return
   fi

   bin="$(command -v mulle-make 2>/dev/null)"
   dynamic="$(__mulle_make_discover_build_options "${bin}")"

   if [[ -n "${dynamic}" ]]; then
      merged="$(__mulle_make_r_merge_words "${__mulle_make_BUILD_OPTIONS}" "${dynamic}")"
   else
      merged="${__mulle_make_BUILD_OPTIONS}"
   fi

   __mulle_make_cache_set build_options "${merged}" "${now}"
   printf '%s' "${merged}"
}


__mulle_make_definition_keys()
{
   local now
   local directory
   local file
   local key
   local keys

   if [[ "${__mulle_make_cached_DEFKEYS_PWD:-}" = "${PWD}" ]]; then
      __mulle_make_cache_get DEFKEYS
      return
   fi

   keys="${__mulle_make_DEFINITION_KEYS}"

   for directory in "${PWD}/.mulle/etc/craft/definition" \
                    "${PWD}/.mulle/share/craft/definition"
   do
      [[ -d "${directory}" ]] || continue

      for file in "${directory}"/set/* "${directory}"/set/*/* \
                  "${directory}"/plus/* "${directory}"/plus/*/*
      do
         [[ -f "${file}" ]] || continue
         key="${file##*/}"
         case " ${keys} " in
            *" ${key} "*)
            ;;
            *)
               keys="${keys} ${key}"
            ;;
         esac
      done
   done

   __mulle_make_cache_set DEFKEYS "${keys}" "$(__mulle_make_epoch)"
   __mulle_make_cached_DEFKEYS_PWD="${PWD}"
   printf '%s' "${keys}"
}


__mulle_make_log_files()
{
   local builddir
   local file
   local files
   local now

   now="$(__mulle_make_epoch)"
   if __mulle_make_cache_valid log_files "${now}"; then
      __mulle_make_cache_get log_files
      return
   fi

   builddir="${PWD}/build"
   if [[ -f "${PWD}/.mulle-make-build-dir" ]]; then
      builddir="$(grep -E -v '^#' "${PWD}/.mulle-make-build-dir" 2>/dev/null)"
      [[ -n "${builddir}" ]] || builddir="${PWD}/build"
   fi

   files=""
   for file in "${builddir}"/.log/*.*.log
   do
      [[ -e "${file}" ]] || continue
      files="${files} ${file##*/}"
   done

   __mulle_make_cache_set log_files "${files}" "${now}"
   printf '%s' "${files}"
}

# --------------------------------------------------------------------------
# completion primitives
# --------------------------------------------------------------------------

__mulle_make_files()
{
   compopt -o filenames 2>/dev/null
   COMPREPLY=( $(compgen -f -- "${cur}") )
}


__mulle_make_dirs()
{
   compopt -o dirnames 2>/dev/null
   COMPREPLY=( $(compgen -d -- "${cur}") )
}


__mulle_make_commands_words()
{
   compopt -o filenames 2>/dev/null
   COMPREPLY=( $(compgen -W "$(__mulle_make_commands)" -- "${cur}") )
   COMPREPLY+=( $(compgen -d -- "${cur}") )
}


__mulle_make_words()
{
   COMPREPLY=( $(compgen -W "$1" -- "${cur}") )
}


__mulle_make_define_words()
{
   local keys
   local prefix

   keys="$(__mulle_make_definition_keys)"
   case "${cur}" in
      -D*)
         prefix="-D"
      ;;
      -U*)
         prefix="-U"
      ;;
      *)
         return
      ;;
   esac
   COMPREPLY=( $(compgen -W "${keys}" -P "${prefix}" -- "${cur#${prefix}}") )
}


__mulle_make_OPTARG_OPTIONS="--args --allow-build-script --build-dir -c --configuration --ccache -d --definition-dir --aux-definition-dir --info-dir --makeinfo-dir -F --frameworks-path -I --include-path -j --cores -l --load --log-dir --path --phase --platform --plugins --plugin-preferences --tools --tool-preferences --project-name --name --project-language --language --project-dialect --dialect -s --sdk --target --targets --toolchain --toolchain-tools-root --xcode-config-file -L --lib-path --library-path --prefix --preferred-library-style --library-style -t --tool --export-command -D -U"


__mulle_make_opt_takes_arg()
{
   local opt="$1"

   case " ${__mulle_make_OPTARG_OPTIONS} " in
      *" ${opt} "*) return 0 ;;
   esac
   return 1
}


__mulle_make_complete_optarg()
{
   local prev="$1"

   COMPREPLY=()

   case "${prev}" in
      # take a file
      --args|-l|--load|--xcode-config-file)
         __mulle_make_files
      ;;

      # take an executable
      --ccache)
         COMPREPLY=( $(compgen -c -- "${cur}") )
      ;;

      # take a directory
      --build-dir|--log-dir|--prefix|--path|--toolchain-tools-root|--definition-dir|-d|--aux-definition-dir|--info-dir|--makeinfo-dir)
         __mulle_make_dirs
      ;;

      # take a search path (colon separated list of directories)
      -F|--frameworks-path|-I|--include-path|-L|--lib-path|--library-path)
         __mulle_make_dirs
      ;;

      -c|--configuration)
         __mulle_make_words "${__mulle_make_CONFIGURATIONS}"
      ;;

      --library-style|--preferred-library-style)
         __mulle_make_words "${__mulle_make_LIBRARY_STYLES}"
      ;;

      --project-language|--language)
         __mulle_make_words "${__mulle_make_LANGUAGES}"
      ;;

      --plugins|--plugin-preferences|--tools|--tool-preferences)
         __mulle_make_words "${__mulle_make_PLUGINS}"
      ;;

      --platform)
         __mulle_make_words "${__mulle_make_PLATFORMS}"
      ;;

      -s|--sdk)
         __mulle_make_words "Default"
      ;;

      # key for a definition option
      -D|-U)
         __mulle_make_words "$(__mulle_make_definition_keys)"
      ;;

      # restrict log output to a buildtool
      -t|--tool)
         __mulle_make_words "${__mulle_make_LOG_TOOLS_UNITS}"
      ;;

      *)
      ;;
   esac
}

# --------------------------------------------------------------------------
# command handling
# --------------------------------------------------------------------------

__mulle_make_find_cmd()
{
   local i
   local w
   local known
   local cmd=""

   known=" $(__mulle_make_commands) "

   for (( i = 1; i < cword; i++ ))
   do
      w="${words[${i}]:-}"
      [[ -n "${w}" && "${w}" != -* ]] || continue
      if [[ "${known}" == *" ${w} "* ]]; then
         cmd="${w}"
         break
      fi
   done
   printf '%s' "${cmd}"
}


__mulle_make_complete_build()
{
   if [[ "${cur}" == -D* || "${cur}" == -U* ]]; then
      __mulle_make_define_words
      return
   fi

   if [[ "${cur}" == -* ]]; then
      __mulle_make_words "$(__mulle_make_build_options)"
   else
      __mulle_make_dirs
   fi
}


__mulle_make_complete_definition()
{
   local i
   local w
   local sub=""
   local positionals=0
   local skip_next=0

   for (( i = 2; i < cword; i++ ))
   do
      w="${words[${i}]:-}"
      if (( skip_next )); then
         skip_next=0
         continue
      fi
      case "${w}" in
         --definition-dir|--aux-definition-dir|--export-command|--prefix)
            skip_next=1
            continue
         ;;
         -h|--help|-*)
            continue
         ;;
      esac
      if [[ -z "${sub}" ]]; then
         sub="${w}"
      else
         (( positionals++ ))
      fi
   done

   # completing the subcommand itself
   if [[ -z "${sub}" ]]; then
      if [[ "${cur}" == -D* || "${cur}" == -U* ]]; then
         __mulle_make_define_words
         return
      fi
      if [[ "${cur}" == -* ]]; then
         __mulle_make_words "${__mulle_make_DEFINITION_OPTIONS}"
      else
         __mulle_make_words "$(__mulle_make_subcommands definition)"
      fi
      return
   fi

   # completing options or positional arguments of a subcommand
   if [[ "${cur}" == -* ]]; then
      case "${sub}" in
         set)         __mulle_make_words "${__mulle_make_DEFINITION_SET_OPTIONS}" ;;
         get)         __mulle_make_words "${__mulle_make_DEFINITION_GET_OPTIONS}" ;;
         list)        __mulle_make_words "${__mulle_make_DEFINITION_LIST_OPTIONS}" ;;
         unset|remove)__mulle_make_words "${__mulle_make_DEFINITION_UNSET_OPTIONS}" ;;
         export)      __mulle_make_words "${__mulle_make_DEFINITION_EXPORT_OPTIONS}" ;;
         write|merge) __mulle_make_words "${__mulle_make_DEFINITION_WRITE_OPTIONS}" ;;
         show|keys|cat) __mulle_make_words "-h --help" ;;
         *)           __mulle_make_words "${__mulle_make_DEFINITION_OPTIONS}" ;;
      esac
      return
   fi

   if (( positionals == 0 )); then
      case "${sub}" in
         set|get|unset|remove)
            __mulle_make_words "$(__mulle_make_definition_keys)"
         ;;
         write|merge|export)
            __mulle_make_dirs
         ;;
         *)
         ;;
      esac
   fi
}


__mulle_make_complete_log()
{
   local i
   local w
   local sub=""
   local logfiles

   logfiles="$(__mulle_make_log_files)"

   for (( i = 2; i < cword; i++ ))
   do
      w="${words[${i}]:-}"
      case "${w}" in
         -t|--tool)
            i=$(( i + 1 ))
            continue
         ;;
         -*)
            continue
         ;;
      esac
      sub="${w}"
      break
   done

   if [[ -n "${sub}" ]]; then
      # subsequent words are arguments to the tool
      __mulle_make_words "${logfiles}"
      return
   fi

   if [[ "${cur}" == -* ]]; then
      __mulle_make_words "${__mulle_make_LOG_OPTIONS}"
   else
      __mulle_make_words "${__mulle_make_LOG_SUBCOMMANDS} ${__mulle_make_LOG_TOOLS} ${logfiles}"
   fi
}

# --------------------------------------------------------------------------
# main completion
# --------------------------------------------------------------------------

_mulle_make_complete()
{
   local cur prev words cword
   local cmd
   local OPTION_TOOL

   if type _get_comp_words_by_ref >/dev/null 2>&1; then
      _get_comp_words_by_ref -n : cur prev words cword
   else
      cur="${COMP_WORDS[COMP_CWORD]:-}"
      prev="${COMP_WORDS[COMP_CWORD-1]:-}"
      cword="${COMP_CWORD:-0}"
      words=( "${COMP_WORDS[@]}" )
   fi

   # first word: flags and commands
   if (( cword == 1 )); then
      __mulle_make_words "${__mulle_make_MAIN_FLAGS} $(__mulle_make_commands)"
      COMPREPLY+=( $(compgen -d -- "${cur}") )
      return
   fi

   # completing the value of a preceding option that takes an argument
   if [[ "${prev}" == -* ]]; then
      if __mulle_make_opt_takes_arg "${prev}"; then
         __mulle_make_complete_optarg "${prev}"
         return
      fi
   fi

   cmd="$(__mulle_make_find_cmd)"

   case "${cmd}" in
      project|build|make|clean|install|craft|list)
         __mulle_make_complete_build
      ;;

      definition)
         __mulle_make_complete_definition
      ;;

      log)
         __mulle_make_complete_log
      ;;

      show)
         if [[ "${cur}" == -* ]]; then
            __mulle_make_words "-h --help"
         fi
      ;;

      uname|version|libexec-dir|library-path)
      ;;

      *)
         # no known command given yet, so the token could still be the
         # command (preceeded by flags) or the source directory argument
         if [[ "${cur}" == -* ]]; then
            __mulle_make_words "$(__mulle_make_build_options)"
         else
            __mulle_make_commands_words
         fi
      ;;
   esac
}

# --------------------------------------------------------------------------
# registration
# --------------------------------------------------------------------------

if type complete >/dev/null 2>&1; then
   complete -o bashdefault -o default -F _mulle_make_complete mulle-make
fi