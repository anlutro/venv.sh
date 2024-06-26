#!/bin/sh

# https://github.com/anlutro/venv.sh
# install by sourcing in your bashrc or zshrc

# ensure script is sourced, not invoked
# https://stackoverflow.com/a/28776166/2490608
_venv_sh_sourced=0
if [ -n "$ZSH_EVAL_CONTEXT" ]; then 
  case $ZSH_EVAL_CONTEXT in *:file) _venv_sh_sourced=1;; esac
elif [ -n "$KSH_VERSION" ]; then
  # shellcheck disable=SC2296
  [ "$(cd "$(dirname -- $0)" && pwd -P)/$(basename -- $0)" != "$(cd "$(dirname -- "${.sh.file}")" && pwd -P)/$(basename -- ${.sh.file})" ] && _venv_sh_sourced=1
elif [ -n "$BASH_VERSION" ]; then
  (return 0 2>/dev/null) && _venv_sh_sourced=1
else # All other shells: examine $0 for known shell binary filenames
  # Detects `sh` and `dash`; add additional shell filenames as needed.
  case ${0##*/} in sh|dash) _venv_sh_sourced=1;; esac
fi

if [ $_venv_sh_sourced -eq 0 ]; then
    echo "$0 must be sourced, not ran as a command!" >&2
    exit 1
fi
unset _venv_sh_sourced

function venv {
    function confirm {
        : "${ask_default:=yes}"

        if [ "$ask" = 'no' ]; then
            if [ "$ask_default" = 'yes' ]; then
                return 0
            fi
            return 1
        fi

        local ask_options
        ask_options="Y/n"
        if [ "$ask_default" = 'no' ]; then
            ask_options="y/N"
        fi

        read -rp "$* [$ask_options] "
        if [[ "$REPLY" =~ ^[Yy] ]]; then
            return 0
        elif [ -z "$REPLY" ] && [ "$ask_default" = 'yes' ]; then
            return 0
        fi
        return 1
    }

    local arg
    local ask
    local func
    local python
    local venv
    local venv_name
    local venv_found

    while [ $# -gt 0 ]; do
        arg="$1"
        case $arg in
            -a|--ask )
                ask='yes'
                ;;
            -n|--no-ask|--noninteractive )
                ask='no'
                ;;
            -p|--python )
                shift
                python="$1"
                ;;
            -p* )
                python="${1:2}"
                ;;
            --python* )
                python="${1:8}"
                ;;
            -2|--two )
                python='python2'
                ;;
            -3|--three )
                python='python3'
                ;;
            -* )
                echo "Unknown option: $arg" >&2
                return 1
                ;;
            * )
                if [ -z "$func" ]; then
                    func="$1"
                elif [ -z "$venv" ]; then
                    venv="$1"
                    venv_name="$1"
                else
                    echo "Extra argument received: $arg" >&2
                    return 1
                fi
                ;;
        esac
        shift
    done

    if [ -z "$venv" ] || [ "$venv" = "$PWD" ] || [ "$venv" = '.' ]; then
        venv=".venv"
    fi

    # remove trailing slash, which is common when autocompleting directories
    if [ -n "$venv_name" ] && [ -e "$venv_name" ]; then
        venv_name="${venv_name%/}"
    fi

    if [ -z "$python" ]; then
        python=$(
            find /usr/local/bin /usr/bin $HOME/.local/bin -regex '.*/python[3-9][0-9.]*' -printf '%f\n' \
            | sort -V | tail -1
        )
        if [ -z "$python" ]; then
            echo "Could not find an appropriate Python binary!" >&2
            echo "Specify one with -p/--python." >&2
            return 1
        fi
    elif echo "$python" | grep -qP '^[\d\.]+$'; then
        python="python${python}"
    fi

    function venv-activate {
        if [ -n "$VIRTUAL_ENV" ]; then
            echo "A virtualenv is already active!" >&2
            return 1
        fi

        venv-locate

        if [ -n "$venv_found" ]; then
            venv="$venv_found"
            if [ ! -e "$venv/bin/python" ]; then
                ls --color=yes -l $venv/bin/python*
                echo "Python binary not found in venv, possibly due to python being upgraded." >&2
                if ! confirm "Re-create virtualenv?"; then
                    return 1
                fi
                venv-destroy
                venv-create
            fi
        else
            echo "Couldn't find a virtualenv in PWD!" >&2
            ask="${ask:-yes}" venv-create || return $?
            venv-activate
            return $?
        fi

        local relpath
        relpath=$(realpath --relative-to=$PWD $venv)
        if echo "$relpath" | grep -q '^\.\.'; then
            relpath=$venv
        fi
        echo -n "Activating virtualenv: $relpath" >&2
        echo " - $($venv/bin/python --version 2>&1)" >&2
        echo "Run \`deactivate\` to exit the virtualenv." >&2
        # shellcheck source=/dev/null
        . $venv/bin/activate
        export VIRTUAL_ENV_NAME="$venv_name"
        # TODO: this is author-specific, can we make it generic?
        if [ "$(type -t _set_ps1)" = 'function' ]; then
            _set_ps1
        fi
    }

    function venv-locate {
        local dir="$PWD"
        local venv_dir
        if [ -d $dir/.tox ]; then
            if [ -n "$venv_name" ]; then
                venv_found=$dir/.tox/$venv_name
            else
                venv_found=$(find $dir/.tox -mindepth 1 -maxdepth 1 -name 'py*' | sort | tail -1)
            fi
            if [ ! -d "$venv_found" ]; then
                echo ".tox directory found but no virtualenvs!" >&2
                return 1
            fi
            venv_name="$(basename $dir)/$(basename $venv_found)"
        else
            for venv_dir in . $venv .virtualenv .venv venv .; do
                if [ -f $venv_dir/bin/activate ]; then
                    venv_found=$venv_dir
                    if [ -z "$venv_name" ]; then
                        venv_name=$(basename $dir)
                    fi
                    break
                fi
            done
        fi
        if [ -n "$venv_found" ]; then
            return 0
        else
            return 1
        fi
    }

    function venv-create {
        local cmd
        local venv_pdir

        if echo "$python" | grep -q 'python3'; then
            cmd="$python -m venv"
        elif command -v virtualenv >/dev/null 2>&1; then
            cmd="virtualenv -p $python"
        elif [ -e /usr/lib/python3/dist-packages/virtualenv.py ]; then
            cmd="python3 -m virtualenv -p $python"
        elif [ -e /usr/lib/python2.7/dist-packages/virtualenv.py ]; then
            cmd="python2.7 -m virtualenv -p $python"
        else
            echo "Don't know how to make a virtualenv for $python" >&2
            return 1
        fi

        echo "Creating virtualenv in '$venv' using $python ($($python --version 2>&1)) ..." >&2
        if ! confirm "Confirm"; then
            return 1
        fi
        $cmd "$venv" || return 1
        echo "Upgrading pip, setuptools, wheel ..." >&2
        "$venv/bin/pip" --quiet install --upgrade pip setuptools wheel

        venv_pdir="$(dirname "$(readlink -f "$venv")")"
        if [ -e "$venv_pdir/pyproject.toml" ]; then
            if grep -qF '[tool.poetry]' "$venv_pdir/pyproject.toml" && ask_default=no confirm "Poetry config detected, install it??"; then
                echo "Installing poetry ..." >&2
                "$venv/bin/pip" --quiet install --upgrade poetry
            fi
        fi

        for f in dev-requirements.txt requirements-dev.txt requirements/dev.txt; do
            if [ -e $f ] && ask_default=no confirm "Install $f?"; then
                $venv/bin/pip install --upgrade -r $f
            fi
        done
    }

    function venv-destroy {
        if ! venv-locate; then
            echo "No virtualenv found!" >&2
            return 0
        fi
        venv="$venv_found"

        if ! confirm "Remove virtualenv '$venv'?"; then
            return 1
        fi

        if [ -n "$VIRTUAL_ENV" ]; then
            deactivate
            # TODO: this is author-specific, can we make it generic?
            if [ "$(type -t _set_ps1)" = 'function' ]; then
                _set_ps1
            fi
        fi
        echo "Removing $venv ..." >&2
        rm -rf $venv
    }

    venv-$func
}
