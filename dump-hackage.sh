#!/bin/sh

OUTER=$(dirname "$0")
DIR=$(mktemp -d)
(cd "$DIR"
 cabal get "$@"
 cd *
 "$OUTER/dump-package.sh")

rm -rf "$DIR"
