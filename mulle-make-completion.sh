# mulle-make completion script
_mulle_make_complete()
{
    local cur prev words cword cmd
    _get_comp_words_by_ref -n : cur prev words cword

    # Global options
    local global_options="-f --force --clear --clear-global-definitions --version -h --help --args"

    # Commands
    local commands="project build make clean definition install craft list log show libexec-dir library-path uname version"

    # First word after script name
    if [[ $cword -eq 1 ]]; then
        COMPREPLY=($(compgen -W "${global_options} ${commands}" -- "$cur"))
        return
    fi

    # Second word or after
    cmd="${words[1]}"

    case "$cmd" in
        -f|--force|--clear|--clear-global-definitions|--version|-h|--help)
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
            # clean [options] [directory? but usually none]
            if [[ "$prev" == "clean" ]]; then
                # options for clean, but from build.sh
                COMPREPLY=($(compgen -W "--help -h --build-dir -D --debug --release --configuration --clean --no-clean --clean-before-build --include-path --library-path --prefix --sdk --platform --log-dir --tool-preferences --no-determine-sdk --frameworks-path --include-path --library-path -j --cores --static --shared --dynamic --library-style -F -I -L -s -j -c -k -K -f --force" -- "$cur"))
            else
                COMPREPLY=()
            fi
            ;;
        project|build|make)
            if [[ "$cword" -eq 2 ]]; then
                COMPREPLY=($(compgen -W "--help -h -D --debug --release --configuration --clean --no-clean --build-dir --include-path --library-path --prefix --sdk --platform --log-dir --tool-preferences --no-determine-sdk --frameworks-path -F -I -L -s -j --cores --static --shared --dynamic --library-style -j -k -K -f --force --mulle-test --verbose-make --set-is-plus" -- "$cur"))
            else
                # directory argument
                COMPREPLY=($(compgen -d -- "$cur"))
            fi
            ;;
        install|craft)
            if [[ "$cword" -eq 2 ]]; then
                COMPREPLY=($(compgen -W "--help -h -D --debug --release --configuration --clean --no-clean --build-dir --include-path --library-path --prefix --sdk --platform --log-dir --tool-preferences --no-determine-sdk --frameworks-path -F -I -L -s -j --cores --static --shared --dynamic --library-style -j -k -K -f --force --mulle-test --verbose-make --set-is-plus" -- "$cur"))
            else
                # src dst, but directories
                COMPREPLY=($(compgen -d -- "$cur"))
            fi
            ;;
        list)
            if [[ "$cur" == -* ]]; then
                COMPREPLY=($(compgen -W "--help -h -D --debug --release --configuration --clean --no-clean --build-dir --include-path --library-path --prefix --sdk --platform --log-dir --tool-preferences --no-determine-sdk --frameworks-path -F -I -L -s -j --cores --static --shared --dynamic --library-style -j -k -K -f --force --mulle-test --verbose-make --set-is-plus" -- "$cur"))
            else
                COMPREPLY=()
            fi
            ;;
        log)
            # log commands: clean, list, or grep etc.
            if [[ $cword -eq 2 ]]; then
                COMPREPLY=($(compgen -W "clean list" -- "$cur"))
            elif [[ $cword -eq 3 ]]; then
                if [[ "${words[2]}" == "list" ]]; then
                    COMPREPLY=()
                elif [[ "${words[2]}" == "clean" ]]; then
                    COMPREPLY=()
                else
                    # assume file or something
                    COMPREPLY=()
                fi
            else
                COMPREPLY=()
            fi
            ;;
        definition)
            # definition subcommands
            if [[ $cword -eq 2 ]]; then
                COMPREPLY=($(compgen -W "cat export get list unset set show write" -- "$cur"))
            else
                local subcmd="${words[2]}"
                case "$subcmd" in
                    unset|set|get|list|cat|export|write)
                        if [[ "$cur" == -* ]]; then
                            case "$subcmd" in
                                set)
                                    COMPREPLY=($(compgen -W "--help --non-additive --additive --concat --concat0 --append --append0 --clobber --ifempty --set-is-plus" -- "$cur"))
                                    ;;
                                get)
                                    COMPREPLY=($(compgen -W "--help --output-key --set-is-plus" -- "$cur"))
                                    ;;
                                list)
                                    COMPREPLY=($(compgen -W "--help --set-is-plus" -- "$cur"))
                                    ;;
                                cat|export|write)
                                    COMPREPLY=($(compgen -W "--help --set-is-plus" -- "$cur"))
                                    ;;
                                unset)
                                    COMPREPLY=($(compgen -W "--help --set-is-plus" -- "$cur"))
                                    ;;
                            esac
                        elif [[ "$subcmd" == "set" || "$subcmd" == "get" || "$subcmd" == "unset" ]]; then
                            # for keys, but since keys are many, perhaps just no completion or fixed
                            COMPREPLY=()
                        else
                            if [[ "$subcmd" == "write" ]]; then
                                COMPREPLY=($(compgen -d -- "$cur"))
                            else
                                COMPREPLY=()
                            fi
                        fi
                        ;;
                    *)
                        COMPREPLY=()
                        ;;
                esac
            fi
            ;;
        show)
            # no subcommands
            if [[ "$cword" -eq 2 ]]; then
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
