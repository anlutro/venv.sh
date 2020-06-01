# venv.sh

Provides a shell function `venv` for working with modern Python 3.5+ virtual environments.

## Installation

`git clone` the repository wherever you like.

Add a line to your `.bashrc` or `.zshrc` sourcing `venv.sh`, for example:

```bash
source "$HOME/code/venv.sh/venv.sh"
```

## Usage

`venv activate` will activate a virtual environment in the current directory. If one is not found, you will be asked if you want to create one. You can also use `venv create` to explicitly make one.

You can use `--noninteractive` to prevent confirm prompts from showing up.

By default, virtual environments will be created with the latest version of Python found in your `$PATH`. You can override this with `-2`, `-3`, or specifying an exact version with `-p` (e.g. `-p3.6` or `-p3.9.0b1`).

By default, the directory name `.venv` will be used. It's recommended that you add this to your (global) gitignore.

`venv destroy` will deactivate and destroy the virtual environment.

You might also want to set up aliases to make these commands more easily accessible:

```bash
alias av='venv activate'
alias rmvenv='venv destroy'
```

## Motivation

This script exists for a few reasons, and I wasn't happy with existing solutions like virtualenvwrapper.

- It's annoying for me to remember whether a virtualenv exists or not for every project I work on. I want a command that does the right thing no matter what the current state is.
- I wanted the command to work with existing virtualenvs created by other tools, like Tox.
- I wanted to customize the way my shell prompt was being changed to indicate whether I was in a virtualenv or not.
- I re-compile Python myself quite often, which sometimes means the virtualenv has to be re-created. This is a manual action, I wanted it automated.
- I didn't want to specify the exact Python version to create a virtualenv with, I want to default to the latest installed on my system.
- When creating a virtualenv, I always want pip and setuptools to be upgraded to the latest version.
- When creating a virtualenv, I want the option to conveniently install setup.py or dev-requirements.txt.
