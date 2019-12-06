#!/bin/bash

function get_next_file() {
	if [[ $1 == "modified" ]]; then
		local NEXT_FILES=$(git status | 
		awk '/Changes not staged for commit:/,0' | 
		awk '$1 ~ /^ *modified:/' | 
		sed s'/modified://')
		a=${GITDIFF_SKIP_NEXT_MODIFIED[@]}
	else
		local NEXT_FILES=$(git status | 
		awk '/Untracked files:/,0' | 
		awk '/\t/,0' | tail -n +1 | 
		awk -F'nothing added' '{print $1}')
		a=${GITDIFF_SKIP_NEXT_NEW[@]}
	fi

	local NEXT_FILE=""	
	for f in $NEXT_FILES; do
		invalid=0
		for s in ${a[@]}; do
			if [[ ${f:0:1} == "." ]]; then
				if [[ $s == $(echo "$DOT_PLACEHOLDER$f" | tr "." "XXX") ]]; then
					invalid=1
					break
				fi
			else
				if [[ $s == $f ]]; then
					invalid=1
					break
				fi
			fi
		done
		if (( invalid == 0 )); then
			NEXT_FILE=$f
			break
		fi
	done
	echo "$NEXT_FILE"	
}

#====================

function do_git() {
	echo "$2 $3"
	arr=()
	for s in ${@:4}; do
		l=$(echo $s | wc -m)
		if [[ $l == "2" ]]; then 
			arr+=('-'$s); 
		else
			if [[ $l != "" ]]; then
				arr+=('--'$s); 
			fi
		fi
	done
	git "$1" $arr $3
}

function gitdiff_process_next() {
	NEXT_FILE=$(get_next_file "modified")
	if [[ -z $NEXT_FILE ]]; then
		NEXT_FILE=$(get_next_file "untracked")

		if [[ -z $NEXT_FILE ]]; then
			echo "$3"
			get_skip_msg
		else
			do_git $1 $2 $NEXT_FILE ${@:5}
			if [[ $4 == "1" ]]; then
				f=$(get_next_file "untracked")
				if [[ ! -z $f ]]; then echo "Next:  $f"; fi
			fi
		fi
	else
		do_git $1 $2 $NEXT_FILE ${@:5}
		if [[ $4 == "1" ]]; then
			f=$(get_next_file "modified")
			if [[ ! -z $f ]]; then echo "Next:  $f"; fi
		fi
	fi
}

function gitdiff_checkout_next() {
	NEXT_FILE=$(get_next_file "modified")

	if [[ -z $NEXT_FILE ]]; then
		NEXT_FILE=$(get_next_file "untracked")

		if [[ -z $NEXT_FILE ]]; then
			echo "Nothing to checkout."
			get_skip_msg
		else
			echo "Remove new file $NEXT_FILE ?"
			read DO_REMOVE
			if [[ $DO_REMOVE == 'y' ]]; then
				rm $NEXT_FILE
				echo 'Removed.'
				f=$(get_next_file "untracked")
				if [[ ! -z $f ]]; then
					echo "Next:  $f"
				fi
			else
				echo 'Unchanged.'
			fi
		fi
	else
		echo "Checkout $NEXT_FILE ?"
			read DO_REMOVE
			if [[ $DO_REMOVE == 'y' ]]; then
				git checkout $@ $NEXT_FILE
				echo 'Removed from working tree.'				
				echo 'Removed.'
				f=$(get_next_file "modified")
				if [[ ! -z $f ]]; then
					echo "Next:  $f"
				fi
			else
				echo 'Unchanged.'
			fi
	fi
}

#========================

function gitdiff_skip_next() {
	NEXT_FILE=$(get_next_file "modified")
	if [[ ! -z $NEXT_FILE ]]; then
		if [[ ${NEXT_FILE:0:1} == "." ]]; then
			export GITDIFF_SKIP_NEXT_MODIFIED=(
				"${GITDIFF_SKIP_NEXT_MODIFIED[@]}" 
				$(echo "$DOT_PLACEHOLDER$NEXT_FILE" | tr "." "XXX")
			)
		else
			export GITDIFF_SKIP_NEXT_MODIFIED=(
				"${GITDIFF_SKIP_NEXT_MODIFIED[@]}" 
				"$NEXT_FILE"
			)
		fi
		echo "Skipping modified file $NEXT_FILE"
	else
		NEXT_FILE=$(get_next_file "untracked")
		if [[ ! -z $NEXT_FILE ]]; then
			if [[ ${NEXT_FILE:0:1} == "." ]]; then
				export GITDIFF_SKIP_NEXT_NEW=(
					"${GITDIFF_SKIP_NEXT_NEW[@]}" 
					$(echo "$DOT_PLACEHOLDER$NEXT_FILE" | tr "." "XXX")
				)
			else
				export GITDIFF_SKIP_NEXT_NEW=(
					"${GITDIFF_SKIP_NEXT_NEW[@]}" 
					"$NEXT_FILE"
				)
			fi
			echo "Skipping new file $NEXT_FILE"
		else 
			echo "Nothing to skip."
			get_skip_msg
		fi
	fi
}

function gitdiff_skip_reset() {
	if [[ ! -z $GITDIFF_SKIP_NEXT_MODIFIED ]] || 
		[[ ! -z $GITDIFF_SKIP_NEXT_NEW ]]; then
		if [[ $1 == "--list" ]] || [[ $1 == "-l" ]]; then
			get_skip_msg
		else
			if [[ -z $1 ]]; then
				get_skip_msg "Reseting skipped modified files:" "Reseting skipped untracked files:"				
				export GITDIFF_SKIP_NEXT_MODIFIED=()
				export GITDIFF_SKIP_NEXT_NEW=()
				echo "Gitdiff skip-next reseted."
			else
				arr1=($(echo "${GITDIFF_SKIP_NEXT_MODIFIED}"))
				arr2=($(echo "${GITDIFF_SKIP_NEXT_NEW}"))
	 			reseted=""
				for s in "${arr1[@]}"; do
					if [[ $s == $1 ]]; then					
						if [[ " ${GITDIFF_SKIP_NEXT_MODIFIED[@]} " =~ " ${s} " ]]; then
							new=()
							for val in "${arr1[@]}"; do						    
							    [[ $val != "$s" ]] && new+=($val)
							done
							export GITDIFF_SKIP_NEXT_MODIFIED=("${new[@]}")
							reseted=$s
						fi
					fi
				done
				for s in "${arr2[@]}"; do
					if [[ $s == $1 ]]; then					
						if [[ " ${GITDIFF_SKIP_NEXT_NEW[@]} " =~ " ${s} " ]]; then
							new=()
							for val in "${arr2[@]}"; do
							    [[ $val != "$s" ]] && new+=($val)
							done
							export GITDIFF_SKIP_NEXT_NEW=("${new[@]}")
							reseted=$s
						fi
					fi
				done
				if [[ $reseted == "" ]]; then
					echo "No such file skipped."
				else
					echo "Resetted: $reseted"
				fi
			fi
		fi
	else
		echo "No skip-next to reset."
	fi	
}

function save_skips() {
   printf "%s\n" "${GITDIFF_SKIP_NEXT_MODIFIED[@]}" > "$SKIP_FILENAME1"
   printf "%s\n" "${GITDIFF_SKIP_NEXT_NEW[@]}" > "$SKIP_FILENAME2"		   
}


function get_skip_msg() {
	if (( ${#GITDIFF_SKIP_NEXT_MODIFIED[@]} != 0 )) && [[ ${GITDIFF_SKIP_NEXT_MODIFIED[0]} != "" ]]; then
		if [[ -z $1 ]]; then
			echo "Skipping modified files:"
		else
			echo $1
		fi
		arr=($(echo "${GITDIFF_SKIP_NEXT_MODIFIED}"))
		for s in ${arr[@]}; do
			echo -e "  $s"
		done
		echo
	fi
	if (( ${#GITDIFF_SKIP_NEXT_NEW[@]} != 0 )) && [[ ${GITDIFF_SKIP_NEXT_NEW[0]} != "" ]]; then
		if [[ -z $2 ]]; then
			echo "Skipping untracked files:"
		else
			echo $2
		fi
		arr=($(echo "${GITDIFF_SKIP_NEXT_NEW}"))
		for s in ${arr[@]}; do
			echo -e "  $s"
		done
		echo
	fi
}

#==============

function get_args() {
	local args=()
	for a in $@; do
		echo ${a:1:1} | tr "amdcsrlh" " "
		if [[ -z $(echo ${a:1:1} | tr "amdcsrlh" " ") ]] || [[ ${a:0:1} != "-" ]]; then			
			local args="${args[@]} $a"
		fi
	done
}

function print_help () {
	echo "+============================================================+"
	echo "|                  QCT - Quick Commit Tool                   |"
	echo "+============================================================+"
	echo "  -a - \`git add\` next file from working tree."
	echo "  -d - \`git diff\` next file from working tree."
	echo "  -c - \`git checkout\` next file from working tree." 
	echo "  -m - \`git mergetool\` next file from working tree."
	echo "  -s - Skip next file from working tree for current commit."
	echo "  -r - Reset skipped files for current commit. If file as an argument is supplied,"
	echo "       reset only that file."
	echo "  -l - List all skipped files."
	echo "  -h - Help."
	echo
	echo " - By next file we mean next modified or untracked file in \`git status\` output." 
	echo " - You can pass any parameter except these used by git resolve to the underlaying git"
	echo "   command (eg. \`-p\` to \`git add\`)."
	echo " - I advise you to make short aliases for above-mentioned commands to make the process"
	echo "   most effective."
	echo
}

#===============

# Get skip files
DOT_PLACEHOLDER="gitdiffplaceholer"
homedir=~
eval homedir=$homedir
SKIP_FILENAME1="$homedir/.gitresolve1"
SKIP_FILENAME2="$homedir/.gitresolve2"

# Import skips 
if [ -f "$SKIP_FILENAME1" ]; then 
	GITDIFF_SKIP_NEXT_MODIFIED=$(cat < "$SKIP_FILENAME1")
else
	if [[ $GITDIFF_SKIP_NEXT_MODIFIED == "" ]]; then export GITDIFF_SKIP_NEXT_MODIFIED=(); else
		export GITDIFF_SKIP_NEXT_MODIFIED="${GITDIFF_SKIP_NEXT_MODIFIED[@]}"
	fi
fi
if [ -f "$SKIP_FILENAME2" ]; then 
	GITDIFF_SKIP_NEXT_NEW=$(cat < "$SKIP_FILENAME2")
else
	if [[ $GITDIFF_SKIP_NEXT_NEW == "" ]]; then export GITDIFF_SKIP_NEXT_NEW=(); else
		export GITDIFF_SKIP_NEXT_NEW="${GITDIFF_SKIP_NEXT_NEW[@]}"
	fi
fi

# Run
run=0
for s in $@; do
	if [[ ${s:0:1} == "-" ]]; then
		run=1
		break
	fi
done
if (( run == 0 )); then
	print_help
	exit 1
fi

while getopts "amdcsrlh" opt; do
	case "${opt}" in
		a) gitdiff_process_next "add" "Added:" "Nothing to add." "1" $(get_args $@)
		   break ;;
		m) gitdiff_process_next "mergetool" "Merging:" "Nothing to merge." "1" $(get_args $@)
		   break ;;
		d) gitdiff_process_next "diff" "Untracked:" "Nothing in the working tree." "0" $(get_args $@)
		   break ;;
		c) gitdiff_checkout_next $(get_args $@)
		   break ;;
		s) gitdiff_skip_next $(get_args $@)
		   save_skips
		   break ;;
		r) gitdiff_skip_reset $(get_args $@)
		   save_skips
		   break ;;
		l) gitdiff_skip_reset "--list"
		   break ;;
		h) print_help
		   break ;;
		*) print_help
		   exit 1
	esac
done

exit 0