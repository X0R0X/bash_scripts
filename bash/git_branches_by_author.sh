#!/bin/bash

if [[ $# -ne 1 ]]; then
	echo "List all local and remote branches with last commit of an author:"
	echo '    Expecting arg: Author name. '
	exit 1
fi

git for-each-ref --format='%(committerdate) %09 %(authorname) %09 %(refname)' | sort -u -k7 | grep $1