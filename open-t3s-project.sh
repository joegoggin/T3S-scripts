#!/bin/bash

# VARIABLES
scriptDir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
configDir="$HOME/.config/t3s"
configFile="$configDir/open.conf"

# FUNCTIONS
function createConfig {
    echo "projectDir=~/Projects" >"$configFile"
}

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

	tmux new-session -d -s secondary -n "Live Servers" "$scriptDir/t3sUtil.sh -d $projectDir/$projectName -w 'Live Servers'; zsh -i"

	echo ""
	echo "Tmux session generated ..."
	echo ""
}

function killSession {
	tmux kill-session -t main >/dev/null 2>&1 &
	mainPid=$!

	tmux kill-session -t secondary >/dev/null 2>&1 &
	secPid=$!

	wait "$mainPid"
	wait "$secPid"

	echo ""
	echo "Session killed ..."
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

# HANDLE CONFIG
mkdir -p "$configDir" || exit 1

[[ -f "$configFile" ]] || createConfig
source "$configFile"

while getopts :p:lk flags; do
	case $flags in
	l)
		cd "$projectDir" || {
			echo "Error: $projectDir is not a directory."
			exit 1
		}
		ls --color=auto
		;;
	k)
		killSession
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
