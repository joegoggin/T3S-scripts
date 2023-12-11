#!/bin/bash

# VARIABLES
scriptDir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
configDir="$HOME/.config/t3s"
configFile="$configDir/open.conf"

# FUNCTIONS
function createConfig {
	cp $scriptDir/defaultConfig/open.conf ~/.config/t3s/open.conf
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
		exit 1
	fi

	tmux new-window -d -t main: -n Tunnel "$scriptDir/tunnel.sh -e $projectDir/$projectName/packages/app/env.ts; zsh -i"
	tmux new-window -d -t main: -n Prisma "$scriptDir/prisma.sh -d $projectDir/$projectName; zsh -i"

	tmux new-session -d -s secondary -n "Live Servers" "$scriptDir/t3sUtil.sh -d $projectDir/$projectName -w 'Live Servers'; zsh -i"

	if grep -q "duplicate session" "$tmuxOutputFile"; then
		echo ""
		echo "Error: Session named secondary already exists."
		echo ""
		echo "Run 'tmux ls' to see list of all running sessions."
		echo ""
		exit 1
	fi

	echo ""
	echo "Tmux session generated ..."
	echo ""
}

function killSession {
	clear

	cd "$projectDir/$projectName" || {
		echo "Error: $projectDir is not a directory."
		exit 1
	}

	echo "Stopping and removing remaining containers ..."
	echo ""
	docker compose down
	echo ""

	echo ""
	echo "Done ... All containers stopped and removed!"
	echo ""

	echo ""
	echo "Killing TMUX Sessions ..."
	echo ""

	tmux kill-session -t main >/dev/null 2>&1 &
	mainPid=$!

	tmux kill-session -t secondary >/dev/null 2>&1 &
	secPid=$!

	wait "$mainPid"
	wait "$secPid"

	echo ""
	echo "Done ... TMUX sessions killed"
	echo ""

}

function attach {
	if [ "$attach" -eq 1 ]; then
		eval $attachSecondaryCMD &>/dev/null &
		tmux a -t main
	fi
}

# HANDLE CONFIG
mkdir -p "$configDir" || exit 1

[[ -f "$configFile" ]] || createConfig
source "$configFile"

# START DOCKER
if ! pgrep dockerd >/dev/null 2>&1; then
	echo ""
	echo "Starting Docker ..."
	echo ""

	eval "$dockerStartCMD"
fi

while getopts :o:lk: flags; do
	case $flags in
	l)
		cd "$projectDir" || {
			echo "Error: $projectDir is not a directory."
			exit 1
		}
		ls --color=auto
		;;
	k)
		projectName=$OPTARG
		killSession
		;;
	o)
		projectName=$OPTARG
		createSession
		attach
		;;
	?)
		echo "Error: -$OPTARG is not an option"
		;;
	esac
done
