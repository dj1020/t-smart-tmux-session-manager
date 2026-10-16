#!/usr/bin/env bash
# Real response fixtures captured from isolated Herdr 0.9.4; paths/IDs are not predictions.
# Environment variables are supplied by the isolated runner.
# shellcheck disable=SC2153
if [[ ${T_HERDR_TEST:-} == 1 ]]; then
	name=${0##*/}
	printf -v call '%s' "$name"
	printf -v args ' <%s>' "$@"
	printf '%s%s\n' "$call" "$args" >> "$CASE/calls"
	case $name in
	herdr)
		[[ $1 == --session && $2 == default ]] || exit 97
		shift 2
		case "$*" in
		'status server --json')
			if [[ ( $SCENARIO == offline || $SCENARIO == startfail ) && ! -f $CASE/started ]]; then
				/bin/cp "$FIX/offline.json" "$CASE/response"
			else /bin/cp "$FIX/running.json" "$CASE/response"; fi
			while IFS= read -r line; do printf '%s\n' "$line"; done < "$CASE/response" ;;
		server) : > "$CASE/started"; [[ $SCENARIO != startfail ]] || exit 1; /bin/sleep 1 ;;
		'workspace list')
			[[ $SCENARIO != listfail ]] || { printf 'query failed\n' >&2; exit 1; }
			if [[ $SCENARIO == reuse ]]; then
				jq '.result.workspaces |= map(.label = "project")' "$FIX/list.json"
				exit 0
			fi
			file=list; [[ $SCENARIO != empty && $SCENARIO != offline ]] || file=empty
			while IFS= read -r line; do printf '%s\n' "$line"; done < "$FIX/$file.json" ;;
		workspace\ create*)
			[[ $SCENARIO != createfail ]] || exit 1
			while IFS= read -r line; do printf '%s\n' "$line"; done < "$FIX/create.json" ;;
		workspace\ focus*) [[ $SCENARIO != focusfail ]] || exit 1 ;;
		'session attach default') [[ $SCENARIO != attachfail ]] || exit 1 ;;
		esac ;;
	zoxide)
		if [[ $* == 'query -l' ]]; then printf '%s\n' "$HOME/project"
		elif [[ $* == 'query known' ]]; then printf '%s\n' "$HOME/project"
		elif [[ $1 == query ]]; then exit 1; fi ;;
	fzf*)
		while IFS= read -r line; do printf '%s\n' "$line"; done > "$CASE/list"
		[[ $SCENARIO != cancel ]] || exit 130
		if [[ $SCENARIO == separator && ! -f $CASE/picked ]]; then
			: > "$CASE/picked"; printf '\nseparator\t-\t———\n'; exit 0
		fi
		printf '\n%s\n' "$PICK" ;;
	tmux) exit 98 ;;
	sleep) /bin/sleep "$@" ;;
	esac
	exit 0
fi
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
FIX=$ROOT/tests/fixtures/herdr
BOX=$(mktemp -d /tmp/t-herdr-tests.XXXXXX)
mkdir -p "$BOX/bin" "$BOX/home/project"
for name in herdr tmux zoxide fzf fzf-tmux sleep; do ln -s "$ROOT/tests/herdr.sh" "$BOX/bin/$name"; done
chmod +x "$ROOT/tests/herdr.sh"
count=0
run() {
	count=$((count + 1)); CASE=$BOX/$count; mkdir -p "$CASE"; : > "$CASE/calls"
	status=0
	env -i PATH="$BOX/bin:/opt/homebrew/bin:/usr/bin:/bin" HOME="$BOX/home" \
		T_HERDR_TEST=1 FIX="$FIX" CASE="$CASE" SCENARIO="$scenario" PICK="$pick" \
		HERDR_ENV="$inside" T_SESSION_NAME_INCLUDE_PARENT="${parent:-}" bash "$ROOT/bin/t" "$@" > "$CASE/out" 2> "$CASE/err" || status=$?
}
has() { rg -q -F -- "$1" "$CASE/calls" || { printf 'FAIL %s missing %s (%s)\n' "$count" "$1" "$BOX"; exit 1; }; }
no() { if rg -q "$1" "$CASE/calls"; then printf 'FAIL %s unexpected %s\n' "$count" "$1"; exit 1; fi; }
ok() { [[ $status == 0 ]] || { printf 'FAIL %s exit %s (%s)\n' "$count" "$status" "$BOX"; exit 1; }; }
bad() { [[ $status != 0 ]] || { printf 'FAIL %s expected failure\n' "$count"; exit 1; }; }
scenario=ready; pick=; inside=1
run 'same label'; ok; has 'workspace> <focus> <w1>'; no 'workspace> <create|session> <attach|zoxide'
run "$BOX/home/project"; ok; has 'workspace> <create> <--cwd>'; has '<--label> <project>'; has 'workspace> <focus> <w1>'
inside=; run 'same label'; ok; has 'session> <attach> <default>'
inside=1; pick=$'workspace\tw2\tsame label'; run; ok; has 'workspace> <focus> <w2>'; no 'workspace> <create'
scenario=empty; pick=$'directory\t~/project\t~/project'; run; ok; has 'workspace> <create>'
scenario=offline; run known; ok; has 'herdr <--session> <default> <server>'; has 'sleep <0.5>'
scenario=ready; run missing; bad; no 'workspace> <create|workspace> <focus|session> <attach'
for scenario in listfail createfail focusfail attachfail; do
	inside=; run "$BOX/home/project"; bad
	case $scenario in
	listfail) no 'workspace> <create|workspace> <focus|session> <attach' ;;
	createfail) no 'workspace> <focus|session> <attach' ;;
	focusfail) no 'session> <attach' ;;
	esac
done
scenario=cancel; run; ok; no 'workspace> <create|workspace> <focus|session> <attach'
scenario=ready; inside=1; printf '#!/bin/sh\ntouch "%s"\n' "$BOX/executed" > "$BOX/home/project/.t"
chmod +x "$BOX/home/project/.t"; run "$BOX/home/project"; ok; [[ ! -e $BOX/executed ]]
scenario=startfail; run known; bad; no 'workspace> <list|workspace> <create|workspace> <focus'
scenario=listfail; pick=; run; bad; no '^fzf|workspace> <create|workspace> <focus'
scenario=ready; mkdir -p "$BOX/home/same label"; run "$BOX/home/same label"; ok
has 'workspace> <create>'; has '<--label> <same_label>'
scenario=ready; pick=$'directory\t~/project\t~/project'; run; ok; no 'zoxide <query> <[^-]'
scenario=ready; inside=1; mkdir -p "$BOX/home/a.b c:d"; run "$BOX/home/a.b c:d"; ok
has '<--label> <a_b_c_d>'
scenario=reuse; run "$BOX/home/project"; ok; has 'workspace> <focus> <w1>'; no 'workspace> <create'
scenario=separator; pick=$'workspace\tw2\tsame label'; run; ok; has 'workspace> <focus> <w2>'
scenario=ready; parent=true; run "$BOX/home/project"; ok; has '<--label> <home/project>'
printf 'PASS %s Herdr cases; artifacts: %s\n' "$count" "$BOX"
