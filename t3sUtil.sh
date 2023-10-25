#!/bin/bash

#VARAIABLES
handleKeys=1

#OPTS
while getopts :d:p: flags; do
	case $flags in
	d)
		projectDir=$OPTARG
		;;
	?)
		echo "Error: -$OPTARG is not an option"
		;;
	esac
done

#FUNCTIONS
function throwDirError {
	echo ""
	echo "Error: $1 is not a directory."
	echo ""
	exit 1
}

function printOpts {
	echo ""
	echo "-- Hit 'r' to restart web server"
	echo "-- Hit 'c' to clear screen"
	echo "-- Hit 'i' to install all packages"
	echo "-- Hit 'n' to install a new package"
	echo "-- Hit 'h' to show options"
	echo "-- Hit 'q' to quit"
	echo ""
}

function startServer {
	if [ -z "$webPid" ]; then
		printOpts

		yarn web &

		while true; do
			pid=$(lsof -i :3000 | awk '$2 == "PID" {next} {print $2; exit}')
			if [ -n "$pid" ]; then
				webPid="$pid"
				break
			fi
			sleep 1
		done
	fi
}

function stopServer {
	if [ -n "$webPid" ]; then
		kill "$webPid"

		while ps -p "$webPid" >/dev/null; do
			sleep 1
		done

		webPid=""
	fi
}

function restartServer {
	stopServer

	clear
	echo ""
	echo "Restarting Web Server ..."
	echo ""

	startServer
}

function installAll {
	stopServer

	echo ""
	echo "Installing Packages ..."
	echo ""

	yarn &
	yarnPid=$!

	wait "$yarnPid"

	clear
	echo ""
	echo "Packages installed ..."
	echo ""
	startServer
}

function installNew {
	handleKeys=0
	stopServer

	echo ""
	read -rp "Enter the name of the package: " packageName

	echo ""
	read -rp "Is the package a dev dependency? y/n: " isDev

	echo ""
	echo "Where would you like to install the package?"
	echo ""
	echo "-- Hit '1' for native only"
	echo "-- Hit '2' for web only"
	echo "-- Hit '3' for native and web"
	echo "-- Hit '4' for server"
	echo "-- Hit '5' for db"
	echo ""

	read -rsn 1 key

	case "$key" in
	1)
		cd "$projectDir/apps/expo" || throwDirError "$projectDir/apps/expo"
		;;
	2)
		cd "$projectDir/apps/next" || throwDirError "$projectDir/apps/next"
		;;
	3)
		cd "$projectDir/packages/app" || throwDirError "$projectDir/packages/app"
		;;
	4)
		cd "$projectDir/packages/server" || throwDirError "$projectDir/packages/server"
		;;
	5)
		cd "$projectDir/packages/db" || throwDirError "$projectDir/packages/db"
		;;
	esac

	echo ""
	echo "Installing $packageName ..."
	echo ""

	if [[ "$isDev" == 'y' || "$isDev" == 'Y' ]]; then
		yarn add -D "$packageName" &
		yarnPid=$!
	else
		yarn add "$packageName" &
		yarnPid=$!
	fi

	wait "$yarnPid"

	clear
	echo ""
	echo "$packageName installed ..."
	echo ""

	cd "$projectDir" || throwDirError "$projectDir"
	startServer
	handleKeys=1
}

#CHANGE TO PROJECT DIRECTORY
if [ -z "$projectDir" ]; then
	echo ""
	echo "Error: Project directory required."
	echo ""
	echo "You can enter a project directory by using the -d flag."
	echo ""
	echo "Example: webServer -d ~/Projects/projectName"
	echo ""
	exit 1
fi

cd "$projectDir" || throwDirError "$projectDir"

#START WEB SERVER
startServer

#HANDLE KEY EVENTS
while :; do
	if [ "$handleKeys" -eq 1 ]; then
		read -rsn 1 key

		case "$key" in
		r)
			restartServer
			;;
		c)
			clear
			printOpts
			;;
		i)
			installAll
			;;
		n)
			installNew
			;;
		h)
			printOpts
			;;

		q)
			stopServer
			break
			;;
		*) ;;
		esac
	fi
done
