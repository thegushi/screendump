#!/usr/bin/env bash
# screen-titles.sh — GNU screen window titles + scrollback capture with git sync
# https://github.com/thegushi/screendump
#
# Requires: bash-preexec (https://github.com/rcaloras/bash-preexec)
#           GNU screen
#
# Source this file from your .bashrc after sourcing bash-preexec:
#
#   [ -f ~/.bash-preexec.sh ] && source ~/.bash-preexec.sh
#   [ -f ~/path/to/screen-titles.sh ] && source ~/path/to/screen-titles.sh

[ -f ~/.bash-preexec.sh ] && source ~/.bash-preexec.sh

# _root_prefix: returns "[root] " if the current effective UID is 0, else "".
# Called on every preexec/precmd so su, sudo -i, ksu, etc. are all detected
# automatically — and the marker clears as soon as you drop back out.
_root_prefix() {
    [ "$(id -u)" -eq 0 ] && echo "[root] " || echo ""
}

# preexec: fires before each command executes.
# Sets the screen window title to "<first_token> <last_token> [hostname]",
# or just "<command> [hostname]" for single-word commands.
# Also stashes the title to a per-window dotfile for screendump to use later.
preexec() {
    local arr=($1)

    # Don't update the title when running screendump itself
    [ "${arr[0]}" = "screendump" ] && return

    local prefix
    prefix=$(_root_prefix)

    if [ "${arr[0]}" = "${arr[-1]}" ]; then
        export SCREEN_TITLE="${prefix}${arr[0]} [$HOST]"
    else
        export SCREEN_TITLE="${prefix}${arr[0]} ${arr[-1]} [$HOST]"
    fi

    /usr/bin/printf "\033k%s\033\\" "$SCREEN_TITLE"
    [ -d ~/scrollback ] && echo "$SCREEN_TITLE" > ~/scrollback/.title.$WINDOW
}

# precmd: fires before each prompt (i.e., after a command finishes).
# Resets title to "bash [hostname]" at the prompt, with [root] prefix if elevated.
precmd() {
    local prefix
    prefix=$(_root_prefix)
    export SCREEN_TITLE="${prefix}bash [$HOST]"
    /usr/bin/printf "\033k%s\033\\" "$SCREEN_TITLE"
    [ -d ~/scrollback ] && echo "$SCREEN_TITLE" > ~/scrollback/.title.$WINDOW
}

# screendump: captures the full scrollback of a screen window to a file,
# then commits and pushes to the scrollback git repo.
#
# Usage:
#   screendump          # dump the current window
#   screendump <n>      # dump window number <n>
#
# Output filenames are derived from the window's stashed title, e.g.:
#   ssh_zimbra10_valiant.isc.org_-202504131045.txt
screendump() {
    local window=${1:-$WINDOW}
    local safe_title

    if [ -n "$1" ]; then
        # Dumping a specific window by number — read its stashed title
        safe_title=$(cat ~/scrollback/.title.$window 2>/dev/null \
            | tr " /[]" "_" \
            | sed "s/__*/_/g")
    else
        # Dumping the current window — use the live SCREEN_TITLE
        safe_title=$(echo "$SCREEN_TITLE" \
            | tr " /[]" "_" \
            | sed "s/__*/_/g")
    fi

    # Fall back to window number if no title is available
    safe_title="${safe_title:-window_${window}}"

    local outfile=~/scrollback/${safe_title}-$(date +%Y%m%d%H%M).txt

    screen -S "$STY" -p "$window" -X hardcopy -h "$outfile" 2>/dev/null \
        && cd ~/scrollback \
        && git add -A \
        && git commit -m "$safe_title" > /dev/null 2>&1 \
        && git push > /dev/null 2>&1 \
        && cd - > /dev/null
}
