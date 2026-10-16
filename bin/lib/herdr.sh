#!/usr/bin/env bash
# Picker globals are consumed by selection.sh.
# shellcheck disable=SC2034

herdr_error() {
	printf 'Herdr: %s\n' "$1" >&2
	return 1
}

herdr_call() {
	herdr --session default "$@"
}

ensure_herdr_server() {
	local status pid
	command -v herdr >/dev/null || { herdr_error 'CLI not found'; return 1; }
	command -v jq >/dev/null || { herdr_error 'jq is required'; return 1; }
	status=$(herdr_call status server --json) || { herdr_error 'server status failed'; return 1; }
	case $(printf '%s\n' "$status" | jq -er '.status') in
	running) return 0 ;;
	not_running)
		herdr_call server </dev/null >/dev/null 2>&1 &
		pid=$!
		sleep 0.5
		if ! kill -0 "$pid" 2>/dev/null; then
			wait "$pid"
			herdr_error 'server exited during startup'
			return 1
		fi ;;
	*) herdr_error 'invalid server status'; return 1 ;;
	esac
}

read_workspaces() {
	local response
	response=$(herdr_call workspace list) || { herdr_error 'workspace query failed'; return 1; }
	printf '%s\n' "$response" | jq -ec '
		select(.result.type == "workspace_list") | .result.workspaces |
		select(type == "array") |
		select(all(.[]; (.workspace_id | type == "string" and length > 0) and
			(.label | type == "string")))' || { herdr_error 'invalid workspace response'; return 1; }
}

list_options() {
	local workspaces directory
	ensure_herdr_server || return 1
	workspaces=$(read_workspaces) || return 1
	printf '%s\n' "$workspaces" | jq -r '.[] | ["workspace", .workspace_id, .label] | @tsv'
	printf 'separator\t-\t———\n'
	while IFS= read -r directory; do
		printf 'directory\t%s\t%s\n' "$directory" "$directory"
	done < <(get_zoxide_results)
}

picker_settings() {
	set_picker_label 'Herdr Mode'
	PICKER_COLOR='label:magenta:bold:reverse,border:magenta'
	PROMPT='>  '
	PICKER_COMMAND=fzf
}

focus_workspace() {
	herdr_call workspace focus "$1" >/dev/null || { herdr_error 'workspace focus failed'; return 1; }
	if [[ ${HERDR_ENV:-} != 1 ]]; then
		herdr_call session attach default || { herdr_error 'session attach failed'; return 1; }
	fi
}

open_workspace_input() {
	local input=$1 workspaces id directory name created
	ensure_herdr_server || return 1
	workspaces=$(read_workspaces) || return 1
	id=''
	if [[ ${2:-} != directory ]]; then
		id=$(printf '%s\n' "$workspaces" | jq -r --arg name "$input" \
			'[.[] | select(.label == $name)][0].workspace_id // empty')
	fi
	if [[ -z $id ]]; then
		if [[ ${2:-} == directory ]]; then
			directory=$input
		else
			directory=$(resolve_input "$(expand_home "$input")") || { herdr_error 'no workspace or directory found'; return 1; }
		fi
		[[ -d $directory ]] || { herdr_error 'directory does not exist'; return 1; }
		directory=$(cd "$directory" && pwd) || return 1
		name=$(get_session_name "$directory")
		id=$(printf '%s\n' "$workspaces" | jq -r --arg name "$name" \
			'[.[] | select(.label == $name)][0].workspace_id // empty')
		if [[ -z $id ]]; then
			created=$(herdr_call workspace create --cwd "$directory" --label "$name" --no-focus) \
				|| { herdr_error 'workspace creation failed'; return 1; }
			id=$(printf '%s\n' "$created" | jq -er \
				'select(.result.type == "workspace_created") | .result.workspace.workspace_id | select(type == "string" and length > 0)') \
				|| { herdr_error 'invalid create response'; return 1; }
		fi
		zoxide add "$directory" >/dev/null 2>&1
	fi
	focus_workspace "$id"
}

open_selection() {
	local kind value label
	IFS=$'\t' read -r kind value label <<< "$1"
	case $kind in
	workspace) focus_workspace "$value" ;;
	directory) open_workspace_directory "$value" ;;
	*) herdr_error 'invalid selection' ;;
	esac
}

open_workspace_directory() {
	# Directory rows must never be confused with a same-named workspace label.
	local directory
	directory=$(expand_home "$1")
	[[ -d $directory ]] || { herdr_error 'directory does not exist'; return 1; }
	open_workspace_input "$(cd "$directory" && pwd)" directory
}
