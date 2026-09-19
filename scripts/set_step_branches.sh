#!/bin/sh

set -eu

cd "$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
set -- $(git rev-list --reverse main)

if [ "$#" -ne 5 ]; then
    echo "Expected main to contain exactly 5 commits; found $#." >&2
    exit 1
fi

git branch --force step1 "$1"
git branch --force step2 "$2"
git branch --force step5 "$3"
git branch --force step7 "$4"
