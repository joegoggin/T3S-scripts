#!/bin/bash

# VARIABLES
scriptDir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
projectDir=~/Projects

function createSession {
	cd "$projectDir/$projectName" || {
		echo ""
		echo "Error: $projectDir/$projectName is not directory."
		echo ""
		exit 1
	}

	tmuxOutputFile=$(mktemp)

	tmux new-session -d -s main -n Neovim "nvim .; zsh -i" >"$tmuxOutputFile" 2>&1

	if grep -q "duplicate session" "$tmuxOutputFile"; then
		echo ""
		echo "Error: Session named main already exists."
		echo ""
		echo "Run 'tmux ls' to see list of all running sessions."
		echo ""
		return
	fi

	tmux new-window -d -t main: -n Tunnel "$scriptDir/tunnel.sh -e $projectDir/$projectName/packages/app/env.ts; zsh -i"
	tmux new-window -d -t main: -n Prisma "$scriptDir/prisma.sh -d $projectDir/$projectName/packages/db; zsh -i"

	tmux new-session -d -s secondary -n "Live Servers" "$scriptDir/t3sUtil.sh -d $projectDir/$projectName; zsh -i" \; split-window -h "yarn native; zsh -i"

	echo ""
	echo "Tmux session generated ..."
	echo ""
}

#START POSTGRESQL
pgOutputFile=$(mktemp)

pg_isready >"$pgOutputFile"

if grep -q "no response" "$pgOutputFile"; then
	echo ""
	echo "Starting postgres ..."
	echo ""

	sudo service postgresql start >/dev/null 2>&1

	echo ""
	echo "Postgres started ..."
fi

rm -rf "$pgOutputFile"

while getopts :p:l flags; do
	case $flags in
	l)
		cd "$projectDir" || {
			echo "Error: $projectDir is not a directory."
			exit 1
		}
		ls --color=auto
		;;
	p)
		projectName=$OPTARG
		createSession
		;;
	?)
		echo "Error: -$OPTARG is not an option"
		;;
	esac
done
