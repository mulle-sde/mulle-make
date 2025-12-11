# mulle-make completion script
_mulle_make_complete()
{
    local cur prev words cword cmd
    _get_comp_words_by_ref -n : cur prev words cword

    # Global options
    local global_options="-f --force --clear --clear-global-definitions --no-clear --no-clear-global-definitions --version -h --help --args"

    # Commands (visible and hidden)
    local commands="project build make clean definition install craft list log show libexec-dir library-path uname version"

    # Common build options
    local build_common_options="-h --help -D -U -d --definition-dir --aux-definition-dir --build-dir --debug --release -c --configuration --include-path --library-path --dynamic --no-ninja --mulle-test --verbose-make -j --cores --static --shared --standalone --preferred-library-style --library-style --frameworks-path -F -I -L"
    
    # Uncommon build options
    local build_uncommon_options="--prefix --append --ifempty --remove --no-determine-sdk --phase --platform --project-name --name --project-language --language --project-dialect --dialect --log-dir --tool-preferences --plugin-preferences --tools --plugins --sdk -s --xcode-config-file --toolchain --target --targets --allow-script --allow-build-script --no-allow-script --allow-unknown-option --no-allow-unknown-option --analyze --no-analyze --ninja --ccache --make --no-make --autoconf --no-autoconf --configure --no-configure --no-cmake --xcodebuild --no-xcodebuild --determine-sdk --prefer-xcodebuild --rerun-cmake --set-is-plus --underline --path --load -l --serial --no-parallel --clean -k --no-clean -K"
    
    local build_options="${build_common_options} ${build_uncommon_options}"

    # First word after script name
    if [[ $cword -eq 1 ]]; then
        COMPREPLY=($(compgen -W "${global_options} ${commands}" -- "$cur"))
        return
    fi

    # Second word or after
    cmd="${words[1]}"

    case "$cmd" in
        -f|--force|--clear|--clear-global-definitions|--no-clear|--no-clear-global-definitions|--version|-h|--help)
            # These are flags, so no completion or just commands
            if [[ $cword -eq 2 ]]; then
                COMPREPLY=($(compgen -W "${commands}" -- "$cur"))
            fi
            ;;
        --args)
            # --args takes a file
            if [[ $cword -eq 2 ]]; then
                COMPREPLY=($(compgen -f -- "$cur"))
            fi
            ;;
        clean)
            if [[ "$cur" == -* ]]; then
                COMPREPLY=($(compgen -W "${build_options}" -- "$cur"))
            else
                COMPREPLY=($(compgen -d -- "$cur"))
            fi
            ;;
        project|build|make)
            if [[ "$cur" == -* ]]; then
                COMPREPLY=($(compgen -W "${build_options}" -- "$cur"))
            else
                # directory argument
                COMPREPLY=($(compgen -d -- "$cur"))
            fi
            ;;
        install|craft)
            if [[ "$cur" == -* ]]; then
                COMPREPLY=($(compgen -W "${build_options}" -- "$cur"))
            else
                # src dst, but directories
                COMPREPLY=($(compgen -d -- "$cur"))
            fi
            ;;
        list)
            if [[ "$cur" == -* ]]; then
                COMPREPLY=($(compgen -W "${build_options}" -- "$cur"))
            else
                COMPREPLY=()
            fi
            ;;
        log)
            # log commands: clean, list, or any tool like cat, grep, etc.
            if [[ $cword -eq 2 ]]; then
                if [[ "$cur" == -* ]]; then
                    COMPREPLY=($(compgen -W "-h --help -t --tool" -- "$cur"))
                else
                    COMPREPLY=($(compgen -W "clean list cat grep ack" -- "$cur"))
                fi
            else
                COMPREPLY=()
            fi
            ;;
        definition)
            # definition subcommands
            if [[ $cword -eq 2 ]]; then
                if [[ "$cur" == -* ]]; then
                    COMPREPLY=($(compgen -W "-h --help -D -U --definition-dir --aux-definition-dir --allow-unknown-option --no-allow-unknown-option" -- "$cur"))
                else
                    COMPREPLY=($(compgen -W "cat export get list unset set show keys write merge remove" -- "$cur"))
                fi
            else
                local subcmd="${words[2]}"
                case "$subcmd" in
                    set)
                        if [[ "$cur" == -* ]]; then
                            COMPREPLY=($(compgen -W "-h --help --non-additive --additive --concat --concat0 --append --append0 --clobber --ifempty --set-is-plus" -- "$cur"))
                        else
                            COMPREPLY=()
                        fi
                        ;;
                    get)
                        if [[ "$cur" == -* ]]; then
                            COMPREPLY=($(compgen -W "-h --help --output-key --set-is-plus" -- "$cur"))
                        else
                            COMPREPLY=()
                        fi
                        ;;
                    list|cat|show|keys)
                        if [[ "$cur" == -* ]]; then
                            COMPREPLY=($(compgen -W "-h --help --set-is-plus" -- "$cur"))
                        else
                            COMPREPLY=()
                        fi
                        ;;
                    export)
                        if [[ "$cur" == -* ]]; then
                            COMPREPLY=($(compgen -W "-h --help --set-is-plus --export-command" -- "$cur"))
                        else
                            COMPREPLY=($(compgen -d -- "$cur"))
                        fi
                        ;;
                    write|merge)
                        if [[ "$cur" == -* ]]; then
                            COMPREPLY=($(compgen -W "-h --help --set-is-plus" -- "$cur"))
                        else
                            COMPREPLY=($(compgen -d -- "$cur"))
                        fi
                        ;;
                    unset|remove)
                        if [[ "$cur" == -* ]]; then
                            COMPREPLY=($(compgen -W "-h --help --set-is-plus" -- "$cur"))
                        else
                            COMPREPLY=()
                        fi
                        ;;
                    *)
                        COMPREPLY=()
                        ;;
                esac
            fi
            ;;
        show)
            if [[ "$cur" == -* ]]; then
                COMPREPLY=($(compgen -W "-h --help" -- "$cur"))
            else
                COMPREPLY=()
            fi
            ;;
        uname|version|libexec-dir|library-path)
            COMPREPLY=()
            ;;
        *)
            if [[ "$cur" == -* ]]; then
                COMPREPLY=($(compgen -W "${global_options}" -- "$cur"))
            else
                COMPREPLY=($(compgen -d -- "$cur"))
            fi
            ;;
    esac

    # If not matched, fallback to file completion
    if [[ ${#COMPREPLY[@]} -eq 0 ]]; then
        COMPREPLY=($(compgen -f -- "$cur"))
    fi
}
complete -F _mulle_make_complete mulle-make
