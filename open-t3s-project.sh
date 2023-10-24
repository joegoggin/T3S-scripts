#!/bin/bash

#START POSTGRESQL
PG_OUTPUT_FILE=$(mktemp)

pg_isready >"$PG_OUTPUT_FILE"

if grep -q "no response" "$PG_OUTPUT_FILE"; then
	echo ""
	echo "Enter password to start postgres ..."
	sudo service postgresql start >/dev/null 2>&1
	echo ""
	echo "Postgres started ..."
fi

rm -rf "$PG_OUTPUT_FILE"

# VARIABLES
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
DEFAULT_PROJECT_DIR=~/Projects

function createSession {
	cd "$DEFAULT_PROJECT_DIR/$PROJECT_NAME" || {
		echo ""
		echo "Error: $DEFAULT_PROJECT_DIR/$PROJECT_NAME is not directory."
		echo ""
		exit 1
	}

	TMUX_OUTPUT_FILE=$(mktemp)

	tmux new-session -d -s main -n Neovim "nvim .; zsh -i" >"$TMUX_OUTPUT_FILE" 2>&1

	if grep -q "duplicate session" "$TMUX_OUTPUT_FILE"; then
		echo ""
		echo "Error: Session named main already exists."
		echo ""
		echo "Run 'tmux ls' to see list of all running sessions."
		echo ""
		return
	fi

	tmux new-window -d -t main: -n Tunnel "$SCRIPT_DIR/tunnel.sh -e $DEFAULT_PROJECT_DIR/$PROJECT_NAME/packages/app/env.ts; zsh -i"
	tmux new-window -d -t main: -n Prisma "$SCRIPT_DIR/prisma.sh -d $DEFAULT_PROJECT_DIR/$PROJECT_NAME/packages/db; zsh -i"

	tmux new-session -d -s secondary -n "Live Servers" "$SCRIPT_DIR/t3sUtil.sh -d $DEFAULT_PROJECT_DIR/$PROJECT_NAME; zsh -i" \; split-window -h "yarn native; zsh -i"

	echo ""
	echo "Tmux session generated ..."
	echo ""
}

while getopts :p:l FLAGS; do
	case $FLAGS in
	l)
		cd "$DEFAULT_PROJECT_DIR" || {
			echo "Error: $DEFAULT_PROJECT_DIR is not a directory."
			exit 1
		}
		ls --color=auto
		;;
	p)
		PROJECT_NAME=$OPTARG
		createSession
		;;
	?)
		echo "Error: -$OPTARG is not an option"
		;;
	esac
done
