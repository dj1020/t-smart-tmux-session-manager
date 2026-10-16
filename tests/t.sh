#!/usr/bin/env bash
# Fixtures deliberately contain literal tmux IDs ($1) and abbreviated ~/ paths.
# shellcheck disable=SC2016,SC2088

# All external commands used by t are isolated; never contact a real server/database.
if [[ ${T_TEST_STUB:-} == 1 ]]; then
	command_name=${0##*/}
	call="$command_name"
	if [[ $command_name != fzf* ]]; then
		call+=" ${1:-}"
		for arg in "${@:2}"; do call+=" <$arg>"; done
	else
		for arg in "$@"; do call+=" <$arg>"; done
	fi
	printf '%s\n' "$call" >> "$TEST_DIR/calls"
	case $command_name in
	tmux)
		case $1 in
		list-sessions)
			[[ $TEST_SERVER == 1 ]] || exit 1
			if [[ $# == 1 ]]; then exit 0; fi
			if [[ $* == *session_last_attached* ]]; then
				printf '10 older\n30 newer\n'
			else
				printf 'older\nnewer\n%s\n' "${TEST_EXISTING:-}"
			fi
			;;
		show | show-option)
			case ${*: -1} in
			@t-fzf-default-results) printf '%s' "${TEST_SOURCE:-}" ;;
			@t-fzf-prompt) printf '%s' "${TEST_PROMPT:-}" ;;
			@t-bind) printf '%s' "${TEST_BIND:-}" ;;
			esac
			;;
		display-message) printf '$1\n' ;;
		esac
		;;
	zoxide)
		case $1 in
		query)
			if [[ ${2:-} == -l ]]; then
				printf '%s\n' "$HOME/project" "$HOME/other"
			elif [[ ${2:-} == known ]]; then
				printf '%s\n' "$HOME/project"
			else exit 1
			fi
			;;
		esac
		;;
	git)
		[[ $* != *clone* ]] || exit 98
		[[ -n ${TEST_GIT_ROOT:-} ]] || exit 1
		case ${*: -1} in
		--show-toplevel) printf '%s\n' "$TEST_GIT_ROOT" ;;
		--git-common-dir) printf '%s\n' "${TEST_GIT_COMMON:-.git}" ;;
		esac
		;;
	fzf | fzf-tmux)
		count=0
		[[ ! -f $TEST_DIR/count ]] || read -r count < "$TEST_DIR/count"
		count=$((count + 1))
		printf '%s\n' "$count" > "$TEST_DIR/count"
		printf '%s\n' "$@" > "$TEST_DIR/args.$count"
		while IFS= read -r line; do printf '%s\n' "$line"; done > "$TEST_DIR/list.$count"
		action=pick
		[[ ! -f $TEST_DIR/action.$count ]] || read -r action < "$TEST_DIR/action.$count"
		case $action in
		cancel) exit 130 ;;
		ctrl-g) printf 'ctrl-g\n%s\n' "$TEST_SELECTION" ;;
		pick)
			for arg in "$@"; do
				if [[ $arg == --expect=ctrl-g ]]; then printf '\n'; break; fi
			done
			printf '%s\n' "$TEST_SELECTION"
			;;
		esac
		;;
	herdr) printf 'ERROR: real Herdr access forbidden\n' >&2; exit 99 ;;
	esac
	exit 0
fi

set -euo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
TARGET=${1:-$ROOT/bin/t}
BASELINE=${2:-}
SANDBOX=$(mktemp -d /tmp/t-tests.XXXXXX)
mkdir -p "$SANDBOX/bin" "$SANDBOX/home/project" "$SANDBOX/home/other"
for command_name in tmux zoxide git fzf fzf-tmux herdr; do
	ln -s "$ROOT/tests/t.sh" "$SANDBOX/bin/$command_name"
done
chmod +x "$ROOT/tests/t.sh"
DISPLAY_HOME='~'
# The original HOME safety regex is invalid on macOS BSD grep (known baseline defect).
[[ $BASELINE != baseline ]] || DISPLAY_HOME="$SANDBOX/home"
passed=0

reset_case() {
	passed=$((passed + 1))
	TEST_DIR="$SANDBOX/case.$passed"
	mkdir -p "$TEST_DIR"
	: > "$TEST_DIR/calls"
	SERVER=1; INSIDE=socket; SELECTION=older; SOURCE=; PROMPT=; EXISTING=
	GIT_ROOT=; GIT_COMMON=.git; USE_GIT=; PARENT=; BORDER=; POPUP=
}

run_t() {
	status=0
	env -i PATH="$SANDBOX/bin:/usr/bin:/bin" HOME="$SANDBOX/home" \
		T_TEST_STUB=1 TEST_DIR="$TEST_DIR" TEST_SERVER="$SERVER" TMUX="$INSIDE" \
		HERDR_ENV=1 TEST_SELECTION="$SELECTION" TEST_SOURCE="$SOURCE" \
		TEST_PROMPT="$PROMPT" TEST_EXISTING="$EXISTING" TEST_GIT_ROOT="$GIT_ROOT" \
		TEST_GIT_COMMON="$GIT_COMMON" T_SESSION_USE_GIT_ROOT="$USE_GIT" \
		T_SESSION_NAME_INCLUDE_PARENT="$PARENT" T_FZF_BORDER_LABEL="$BORDER" \
		FZF_TMUX_OPTS="$POPUP" bash "$TARGET" "$@" \
		> "$TEST_DIR/out" 2> "$TEST_DIR/err" || status=$?
	if rg -q '^herdr|git .*clone' "$TEST_DIR/calls"; then
		printf 'FAIL: forbidden external call in %s\n' "$TEST_DIR" >&2; exit 1
	fi
}

contains() { rg -q -F -- "$2" "$1" || fail "missing '$2' in $1"; }
absent() { if rg -q -e "$2" "$1"; then fail "unexpected '$2' in $1"; fi; }
fail() { printf 'FAIL case %s: %s (artifacts: %s)\n' "$passed" "$1" "$SANDBOX" >&2; exit 1; }
ok() { [[ $status == 0 ]] || fail "exit $status"; printf 'ok %s - %s\n' "$passed" "$1"; }

# Preserved behavior from spec.md LIST-1..3/8, ACT-1..8, ENV-1..3, CUR-1/3.
reset_case; run_t
contains "$TEST_DIR/calls" 'tmux switch-client <-t> <older>'
contains "$TEST_DIR/calls" 'fzf-tmux'
contains "$TEST_DIR/calls" '#{!=:#{session_id},$1}'
[[ $(< "$TEST_DIR/list.1") == "$(printf 'newer\nolder\n———\n%s/project\n%s/other' "$DISPLAY_HOME" "$DISPLAY_HOME")" ]] || fail 'MRU/source order'
absent "$TEST_DIR/calls" 'new-session'; ok 'attached session MRU, exclusion, switch'

reset_case; SELECTION="$SANDBOX/home/project"; run_t
contains "$TEST_DIR/calls" "tmux new-session <-d> <-s> <project> <-c> <$SELECTION>"
contains "$TEST_DIR/calls" "zoxide add <$SELECTION>"; ok 'directory creation and history'

reset_case; SELECTION="$DISPLAY_HOME/project"; EXISTING=project; run_t
contains "$TEST_DIR/calls" 'tmux switch-client <-t> <project>'
absent "$TEST_DIR/calls" 'new-session'; ok 'home expansion and existing session'

reset_case; SELECTION="$SANDBOX/home/project"; : > "$SELECTION/.t"; run_t
contains "$TEST_DIR/calls" "<-c> <$SELECTION> <$SELECTION/.t>"; ok 'startup script only on new session'

reset_case; run_t known
contains "$TEST_DIR/calls" 'tmux switch-client <-t> <project>'
absent "$TEST_DIR/calls" '^fzf'; ok 'direct zoxide name'

reset_case; run_t "$SANDBOX/home/other"
contains "$TEST_DIR/calls" 'tmux switch-client <-t> <other>'; ok 'direct local path'

reset_case; run_t missing
[[ $status != 0 ]] || fail 'missing directory accepted'
contains "$TEST_DIR/out" 'No directory found.'
absent "$TEST_DIR/calls" 'new-session|switch-client|attach'; printf 'ok %s - missing direct path\n' "$passed"

reset_case; SOURCE=sessions; run_t
[[ $(< "$TEST_DIR/list.1") == $'newer\nolder\n———' ]] || fail 'sessions setting'; ok 'sessions source option'

reset_case; SOURCE=zoxide; run_t
[[ $(< "$TEST_DIR/list.1") == "$(printf '%s/project\n%s/other' "$DISPLAY_HOME" "$DISPLAY_HOME")" ]] || fail 'zoxide setting'; ok 'zoxide source option'

reset_case; PROMPT='custom> '; BORDER='Custom'; POPUP='-p 60%,70%'; run_t
contains "$TEST_DIR/args.1" 'custom> '; contains "$TEST_DIR/args.1" 'Custom'
contains "$TEST_DIR/args.1" '60%,70%'; ok 'prompt, border and popup settings'

reset_case; SELECTION="$SANDBOX/home/a.b c:d"; mkdir -p "$SELECTION"; run_t
contains "$TEST_DIR/calls" '<-s> <a_b_c_d>'; ok 'session name normalization'

reset_case; PARENT=true; SELECTION="$SANDBOX/home/other"; run_t
contains "$TEST_DIR/calls" '<-s> <home/other>'; ok 'parent name option'

reset_case; USE_GIT=true; GIT_ROOT="$SANDBOX/home/project"; SELECTION="$GIT_ROOT/src"; run_t
contains "$TEST_DIR/calls" '<-s> <project/src>'; ok 'Git root name'

reset_case; USE_GIT=true; GIT_ROOT="$SANDBOX/home/project"; GIT_COMMON="$GIT_ROOT/.git"
SELECTION="$GIT_ROOT/trees/topic/src"; run_t
contains "$TEST_DIR/calls" '<-s> <project/trees/topic/src>'; ok 'worktree name'

reset_case; USE_GIT=true; SELECTION="$SANDBOX/home/other"; run_t
contains "$TEST_DIR/calls" '<-s> <other>'; ok 'non-Git fallback'

reset_case; printf 'cancel\n' > "$TEST_DIR/action.1"; run_t
absent "$TEST_DIR/calls" '^tmux (new-session|switch-client|attach)|^zoxide add'
[[ ! -s $TEST_DIR/out ]] || fail 'cancellation output'; ok 'quiet cancellation'

# Original detached/serverless cases require a mode switch only in the new version.
for SERVER_CASE in 1 0; do
	reset_case; SERVER=$SERVER_CASE; INSIDE=; SELECTION="$SANDBOX/home/other"
	if [[ $BASELINE != baseline ]]; then printf 'ctrl-g\n' > "$TEST_DIR/action.1"; fi
	run_t
	contains "$TEST_DIR/calls" 'tmux attach <-t> <other>'
	absent "$TEST_DIR/calls" 'switch-client|fzf-tmux'
	if [[ $SERVER == 0 ]]; then
		index=1; [[ $BASELINE == baseline ]] || index=2
		[[ $(< "$TEST_DIR/list.$index") == "$(printf '%s/project\n%s/other' "$DISPLAY_HOME" "$DISPLAY_HOME")" ]] || fail 'serverless source'
	fi
	ok "detached/serverless attach (server=$SERVER)"
done

if [[ $BASELINE == baseline ]]; then
	printf 'PASS: %s baseline cases; artifacts: %s\n' "$passed" "$SANDBOX"; exit 0
fi

# Approved changes: TC-1..11, REQ-1..5/7..9; REQ-6 is deliberately deferred.
reset_case; run_t
absent "$TEST_DIR/args.1" 'ctrl-g|ctrl-s|ctrl-x|ctrl-f'
contains "$TEST_DIR/args.1" 'Tmux Mode'
contains "$TEST_DIR/args.1" 'tab:down,btab:up'; ok 'locked tmux mode and retained navigation'

reset_case; INSIDE=; SELECTION='[示意 workspace] demo'; run_t
contains "$TEST_DIR/list.1" '[示意 workspace] demo'
[[ $(< "$TEST_DIR/list.1") == $'[示意 workspace] demo\n———\n~/project\n~/other' ]] || fail 'stub ordering'
contains "$TEST_DIR/args.1" 'Herdr Mode'; contains "$TEST_DIR/args.1" '--expect=ctrl-g'
contains "$TEST_DIR/out" 'herdr workspace focus <workspace-id>'
contains "$TEST_DIR/out" '未執行'; absent "$TEST_DIR/calls" '^tmux|zoxide add'; ok 'default stub, illustrative workspace preview'

reset_case; INSIDE=; printf 'ctrl-g\n' > "$TEST_DIR/action.1"
printf 'ctrl-g\n' > "$TEST_DIR/action.2"; run_t
contains "$TEST_DIR/args.1" 'Herdr Mode'; contains "$TEST_DIR/args.2" 'Tmux Mode'
contains "$TEST_DIR/args.3" 'Herdr Mode'
contains "$TEST_DIR/args.1" 'label:magenta:bold:reverse,border:magenta'
contains "$TEST_DIR/args.2" 'label:blue:bold:reverse,border:blue'
contains "$TEST_DIR/list.2" 'newer'; absent "$TEST_DIR/list.3" 'newer'
[[ $(< "$TEST_DIR/args.1") == "$(< "$TEST_DIR/args.3")" ]] || fail 'stale backend settings'
[[ $(< "$TEST_DIR/args.1") != "$(< "$TEST_DIR/args.2")" ]] || fail 'identical mode colors'
contains "$TEST_DIR/out" '未執行'; absent "$TEST_DIR/calls" '^tmux (attach|switch-client|new-session)'; ok 'two-way mode lifecycle and action ownership'

reset_case; INSIDE=; SELECTION='~/project'; run_t
contains "$TEST_DIR/out" "herdr workspace create --cwd $SANDBOX/home/project"
contains "$TEST_DIR/out" 'herdr workspace focus <workspace-id>'
contains "$TEST_DIR/out" 'create 結果'
contains "$TEST_DIR/out" 'herdr # 開啟／附加 Herdr TUI'
contains "$TEST_DIR/out" '未執行'; absent "$TEST_DIR/calls" '^tmux|zoxide add'; ok 'stub create, focus and open preview'

for arg in known "$SANDBOX/home/other" demo; do
	reset_case; INSIDE=; run_t "$arg"
	contains "$TEST_DIR/out" 'herdr workspace'; contains "$TEST_DIR/out" '未執行'
	absent "$TEST_DIR/calls" '^tmux|^fzf|zoxide add'; ok "stub direct input: $arg"
done

for flag in -r --repo; do
	for context in socket ''; do
		for url in '' example.git; do
			reset_case; INSIDE=$context; run_t "$flag" "$url"
			[[ $status != 0 ]] || fail 'legacy repo flag accepted'
			contains "$TEST_DIR/err" 'not supported'
			[[ ! -s $TEST_DIR/calls ]] || fail 'repo flag caused external calls'
			printf 'ok %s - rejected %s (tmux=%s, url=%s)\n' "$passed" "$flag" "$context" "$url"
		done
	done
done

reset_case; INSIDE=; printf 'cancel\n' > "$TEST_DIR/action.1"; run_t
[[ ! -s $TEST_DIR/out ]] || fail 'stub cancellation output'
absent "$TEST_DIR/calls" '^tmux|zoxide add'; ok 'quiet stub cancellation'

reset_case; run_t --help
contains "$TEST_DIR/out" 'ctrl-g'; contains "$TEST_DIR/out" 'stub'
absent "$TEST_DIR/out" 'ctrl-s|ctrl-x|ctrl-f|T_REPOS_DIR'
ok 'help documents approved scope'

for context in socket ''; do
	reset_case; INSIDE=$context; SELECTION=; run_t
	[[ ! -s $TEST_DIR/out ]] || fail 'empty selection output'
	absent "$TEST_DIR/calls" '^tmux (attach|switch-client|new-session)|^zoxide add'
	ok "empty selection (tmux=$context)"
done

reset_case; INSIDE=; printf 'ctrl-g\n' > "$TEST_DIR/action.1"
printf 'cancel\n' > "$TEST_DIR/action.2"; run_t
[[ ! -s $TEST_DIR/out ]] || fail 'mode-switch cancellation output'
absent "$TEST_DIR/calls" '^tmux (attach|switch-client|new-session)|^zoxide add'
ok 'cancel after mode switch'

reset_case; SELECTION="$SANDBOX/home/space dir"; mkdir -p "$SELECTION"
: > "$SELECTION/.t"; USE_GIT=true; GIT_ROOT="$SELECTION"; run_t "$SELECTION"
contains "$TEST_DIR/calls" "<-s> <space_dir> <-c> <$SELECTION> <$SELECTION/.t>"
ok 'Git path and startup script containing spaces'

reset_case; INSIDE=; SELECTION="$SANDBOX/home/space dir"; run_t "$SELECTION"
contains "$TEST_DIR/out" 'space\ dir'
contains "$TEST_DIR/out" '未執行'; absent "$TEST_DIR/calls" '^tmux|zoxide add'
ok 'stub shell-escaped path and no startup execution'

for flag in -h --help; do
	reset_case; INSIDE=; run_t "$flag"
	contains "$TEST_DIR/out" 'stub'; absent "$TEST_DIR/calls" '^tmux|^fzf'
	ok "outside-tmux help ($flag)"
done

contains "$ROOT/README.md" 'ctrl-g'
absent "$ROOT/README.md" 'ctrl-s|ctrl-x|ctrl-f|T_REPOS_DIR|find-binding'
printf 'PASS: %s cases; artifacts: %s\n' "$passed" "$SANDBOX"
