#!/usr/bin/env bash
# Literal ~/ is the display format, not a shell expansion.
# shellcheck disable=SC2088

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

get_zoxide_results() {
	local directory
	while IFS= read -r directory; do
		if [[ $directory == "$HOME/"* ]]; then directory="~/${directory#"$HOME/"}"; fi
		printf '%s\n' "$directory"
	done < <(zoxide query -l)
}

expand_home() {
	if [[ $1 == '~/'* ]]; then printf '%s\n' "$HOME/${1#\~/}"; else printf '%s\n' "$1"; fi
}

resolve_input() {
	local directory
	if directory=$(zoxide query "$1" 2>/dev/null); then
		printf '%s\n' "$directory"
	elif [[ -d $1 ]]; then
		printf '%s\n' "$1"
	else
		return 1
	fi
}

show_picker() {
	local -a options popup_options
	local items
	picker_settings
	items=$(list_options) || return 2
	options=(--bind 'tab:down,btab:up' --border-label "$BORDER_LABEL"
		--color "$PICKER_COLOR" --header "$HEADER" --no-sort --prompt "$PROMPT")
	if [[ $MODE_LOCKED == false ]]; then options+=(--expect=ctrl-g); fi
	if [[ $MODE == herdr ]]; then options+=(--delimiter=$'\t' --with-nth=3..); fi
	if [[ $PICKER_COMMAND == fzf-tmux ]]; then
		# Preserve the existing whitespace-separated popup option convention without eval.
		read -r -a popup_options <<< "${FZF_TMUX_OPTS:--p 53%,58%}"
		printf '%s\n' "$items" | fzf-tmux "${options[@]}" "${popup_options[@]}"
	else
		printf '%s\n' "$items" | fzf "${options[@]}" --border
	fi
}

set_picker_label() {
	BORDER_LABEL=" ${T_FZF_BORDER_LABEL:+$T_FZF_BORDER_LABEL — }$1 "
	HEADER=' tab/shift-tab navigate'
	if [[ $MODE_LOCKED == false ]]; then HEADER+=' | ctrl-g switch mode'; fi
}
