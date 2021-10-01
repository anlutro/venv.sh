#!/bin/bash

root="$(dirname "$(readlink -f "$0")")"

# this command is expected to fail
$SHELL $root/venv.sh && exit 1

# ... whereas this should work.
source "$root/venv.sh"

venv create --noninteractive || exit 1
venv activate --noninteractive || exit 2
test "$(which python)" = "$root/.venv/bin/python" || exit 3

echo
echo "Tests were successful!"
