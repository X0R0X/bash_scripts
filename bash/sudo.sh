#!/bin/bash

sudo echo > /dev/null
excode=$?
if [[ $excode -eq 0 ]]; then
	sudo "$@"
else
	return 1
fi

if [[ $PS1 != *"(sudo)"* ]] && [[ $excode -eq 0 ]]; then
	export PS1="\e[0;31m(sudo)\e[39m "$PS1
fi