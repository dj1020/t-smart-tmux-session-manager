#!/usr/bin/env bash
# Picker globals are consumed by selection.sh after this backend is sourced.
# shellcheck disable=SC2034

get_tmux_runtype() {
	T_RUNTYPE=serverless
	if tmux list-sessions &>/dev/null; then
		if [[ -n $TMUX ]]; then T_RUNTYPE=attached; else T_RUNTYPE=detached; fi
	fi
}

get_sessions_by_mru() {
	local current_sid=''
	if [[ $T_RUNTYPE == attached ]]; then
		current_sid=$(tmux display-message -p '#{session_id}')
	fi
	tmux list-sessions -f "#{!=:#{session_id},$current_sid}" \
		-F '#{session_last_attached} #{session_name}' \
		| sort -nr | awk '{print $2}; END {print "———"}'
}

list_options() {
	local source=''
	get_tmux_runtype
	if [[ $T_RUNTYPE != serverless ]]; then
		source=$(tmux show -gqv '@t-fzf-default-results')
		case $source in
		sessions) get_sessions_by_mru ;;
		zoxide) get_zoxide_results ;;
		*) get_sessions_by_mru; get_zoxide_results ;;
		esac
	else
		get_zoxide_results
	fi
}

picker_settings() {
	get_tmux_runtype
	set_picker_label 'Tmux Mode'
	# Reverse gives the title a contrasting background using fzf's documented color API.
	PICKER_COLOR='label:blue:bold:reverse,border:blue'
	PROMPT='>  '
	PICKER_COMMAND=fzf
	if [[ $T_RUNTYPE != serverless ]]; then
		PROMPT=$(tmux show -gqv '@t-fzf-prompt')
		PROMPT=${PROMPT:-'>  '}
	fi
	if [[ $T_RUNTYPE == attached ]]; then PICKER_COMMAND=fzf-tmux; fi
}

get_session_name() {
	local result=$1 git_root basename relative_path git_common
	if [[ $result != /* ]]; then
		printf '%s\n' "$result"
	elif [[ $T_SESSION_USE_GIT_ROOT == true ]]; then
		if git_root=$(git -C "$result" rev-parse --show-toplevel 2>/dev/null); then
			basename=$(basename "$git_root")
			relative_path=${result#"$git_root"}
			if git_common=$(git -C "$result" rev-parse --git-common-dir 2>/dev/null) \
				&& [[ ! $git_common =~ ^(\.\./)*\.git$ ]]; then
				git_common=${git_common%/.git}
				git_common=${git_common%/.bare}
				basename=$(basename "$git_common")
				relative_path=${result#"$git_common"}
			fi
			printf '%s\n' "$basename$relative_path" | tr ' .:' '_'
		else
			basename "$result" | tr ' .:' '_'
		fi
	elif [[ $T_SESSION_NAME_INCLUDE_PARENT == true ]]; then
		printf '%s\n' "$result" | tr ' .:' '_' | awk -F '/' '{print $(NF-1)"/"$NF}'
	else
		basename "$result" | tr ' .:' '_'
	fi
}

create_session() {
	local session=$1 directory=$2
	if [[ -e $directory/.t ]]; then
		tmux new-session -d -s "$session" -c "$directory" "$directory/.t"
	else
		tmux new-session -d -s "$session" -c "$directory"
	fi
}

connect_session() {
	if [[ $T_RUNTYPE == attached ]]; then
		tmux switch-client -t "$1"
	else
		tmux attach -t "$1"
	fi
}

open_selection() {
	local result session_name session=''
	result=$(expand_home "$1")
	zoxide add "$result" &>/dev/null
	session_name=$(get_session_name "$result")
	get_tmux_runtype
	if [[ $T_RUNTYPE != serverless ]]; then
		session=$(tmux list-sessions -F '#S' | grep -Fx -- "$session_name")
	fi
	if [[ -z $session ]]; then
		session=$session_name
		create_session "$session" "$result" || return
	fi
	connect_session "$session"
}
