#!/bin/bash
``
if [[ $# -ne 2 ]]; then
	echo "Expecting 2 args: target-branch and source-branch."
	exit 1
fi

git checkout $2
git rebase --onto $1 `git merge-base $1 $2`
