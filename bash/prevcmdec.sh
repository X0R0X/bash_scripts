#!/bin/bash

set_smile() {
  local exco=$?

  if [[ $PS1 == *":]"* ]]; then  
    PS1=${PS1/'\e[32m:]\e[39m '/''}
  elif [[ $PS1 == *":["* ]]; then
    PS1=${PS1/'\e[91m:[\e[39m '/''}
  elif [[ $PS1 == *":X"* ]]; then
    PS1=${PS1/'\e[91m:X\e[39m '/''}
  elif [[ $PS1 == *":'["* ]]; then
    PS1=${PS1/"\e[91m:'[\e[39m "/''}
  else
    PS1=${PS1/'\e[33m:|\e[39m '/''}
  fi

  if [[ $exco == 0 ]]; then
    PS1='\e[32m:]\e[39m '$PS1
  elif [[ $exco == 130 ]]; then # Ctrl+C    
    PS1='\e[33m:|\e[39m '$PS1
  elif [[ $exco == 127 ]]; then # cmd not found
    PS1='\e[91m:X\e[39m '$PS1
  elif [[ $exco == 137 ]]; then # kill -9
    PS1="\e[91m:'[\e[39m "$PS1
  else
    PS1='\e[91m:[\e[39m '$PS1
  fi
  echo $PS1
}

declare -r PROMPT_COMMAND='PS1=$(set_smile)'
