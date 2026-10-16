#!/usr/bin/env bash
# Literal ~/ is the display format, not a shell expansion.
# shellcheck disable=SC2088

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
	elif [[ -e $1 ]]; then
		printf '%s\n' "$1"
	else
		return 1
	fi
}

show_picker() {
	local -a options popup_options
	picker_settings
	options=(--bind 'tab:down,btab:up' --border-label "$BORDER_LABEL"
		--color "$PICKER_COLOR" --header "$HEADER" --no-sort --prompt "$PROMPT")
	if [[ $MODE_LOCKED == false ]]; then options+=(--expect=ctrl-g); fi
	if [[ $PICKER_COMMAND == fzf-tmux ]]; then
		# Preserve the existing whitespace-separated popup option convention without eval.
		read -r -a popup_options <<< "${FZF_TMUX_OPTS:--p 53%,58%}"
		list_options | fzf-tmux "${options[@]}" "${popup_options[@]}"
	else
		list_options | fzf "${options[@]}" --border
	fi
}

set_picker_label() {
	BORDER_LABEL=" ${T_FZF_BORDER_LABEL:+$T_FZF_BORDER_LABEL — }$1 "
	HEADER=' tab/shift-tab navigate'
	if [[ $MODE_LOCKED == false ]]; then HEADER+=' | ctrl-g switch mode'; fi
}
