#!/usr/bin/env bash
# Picker globals are consumed by selection.sh after this backend is sourced.
# shellcheck disable=SC2034

list_options() {
	printf '[示意 workspace] demo\n———\n'
	get_zoxide_results
}

picker_settings() {
	set_picker_label 'Herdr Mode (stub)'
	PICKER_COLOR='label:magenta:bold:reverse,border:magenta'
	PROMPT='stub>  '
	PICKER_COMMAND=fzf
}

open_selection() {
	local item
	item=$(expand_home "$1")
	printf 'Herdr stub：尚未實作，以下預期命令未執行。\n'
	if [[ -d $item || $item == /* ]]; then
		printf 'herdr workspace create --cwd %q\n' "$item"
		printf '# <workspace-id> 須取自上方 create 結果；此處僅為佔位符。\n'
		printf 'herdr workspace focus <workspace-id>\n'
	else
		# Names/demo labels are not real workspace IDs. Do not invent an executable ID.
		printf 'herdr workspace focus <workspace-id>（需取得 %s 的真實 ID；未執行）\n' "$item"
	fi
	# The foreground TUI comes last so it does not block the preceding focus command.
	printf 'herdr # 開啟／附加 Herdr TUI；未執行\n'
}
