#!/bin/bash

#VARAIABLES
handleKeys=1

#OPTS
while getopts :d:w:p: flags; do
	case $flags in
	w)
		windowName=$OPTARG
		;;
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
	echo "-- Hit 'x' to remove a package"
	echo "-- Hit 'h' to show options"
	echo "-- Hit 'q' to quit"
	echo ""
}

function printLocations {
	echo ""
	echo "-- Hit '1' for native only"
	echo "-- Hit '2' for web only"
	echo "-- Hit '3' for native and web"
	echo "-- Hit '4' for server"
	echo "-- Hit '5' for db"

	if [ -d "$projectDir/packages/email" ]; then
		echo "-- Hit '6' for email"
	fi

	echo ""
}

function startServer {
	if [ -z "$webPid" ]; then
		printOpts

		tmux split-window -h -t "$windowName" -d "echo ''; echo 'Restarting native server ...'; echo ''; yarn native"
		yarn web &

		while true; do
			pid=$(lsof -i :3000 | awk '$2 == "PID" {next} {print $2; exit}')
			if [ -n "$pid" ]; then
				webPid="$pid"
				break
			fi
			sleep 1
		done

		xdg-open http://localhost:3000
	fi
}

function stopServer {
	if [ -n "$webPid" ]; then
		tmux send-keys -t 2 C-c
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

	clear
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

function cdByKey {
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
	6)
		if [ -d "$projectDir/packages/email" ]; then
			cd "$projectDir/packages/email" || throwDirError "$projectDir/packages/email"
		fi
		;;

	esac
}

function search {
	searchOutputFile=$(mktemp)

	npm search "$packageName" >"$searchOutputFile" &
	sePid=$!

	wait "$sePid"

	searchOutput=$(cat "$searchOutputFile")

	searchResult=$(echo "$searchOutput" | head -n 2 | tail -n 1 | awk '{print $1}')
}

function installNew {
	handleKeys=0
	stopServer

	clear
	echo ""
	read -rp "Enter the name of the package: " packageName

	while true; do
		search

		if [ "$searchResult" == "$packageName" ]; then
			break
		else
			clear
			echo ""
			echo "Error: $packageName doesn't exist."
			echo ""
			read -rp "Enter a valid package name: " packageName
		fi
	done

	echo ""
	read -rp "Is the package a dev dependency? y/n: " isDev

	echo ""
	echo "Where would you like to install the package?"
	printLocations

	read -rsn 1 key

	cdByKey

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

function remove {
	handleKeys=0
	stopServer

	clear
	echo ""
	read -rp "Enter the name of the package: " packageName

	echo ""
	echo "Where is the package installed?"
	printLocations

	read -rsn 1 key

	cdByKey

	removePackage=1

	while true; do
		dependencies=$(jq -r '.dependencies | keys_unsorted[]' package.json)
		devDependencies=$(jq -r '.devDependencies | keys_unsorted[]' package.json)

		if (
			echo "$dependencies"
			echo "$devDependencies"
		) | grep -q "\"$packageName\""; then
			break
		else
			clear
			echo ""
			echo "Error: $packageName is not installed at that location."
			echo ""
			echo "Current Directory: $(pwd)"
			echo ""
			echo "Installed Packages:"
			echo ""
			echo "$dependencies"
			echo "$devDependencies"
			echo ""
			read -rp "Would you like to check another location? y/n: " checkAgain

			if [[ "$checkAgain" == 'y' || "$checkAgain" == "Y" ]]; then
				printLocations

				read -rsn 1 key

				cdByKey
			else
				removePackage=0
				clear
				break
			fi
		fi
	done

	if [ "$removePackage" -eq 1 ]; then
		yarn remove "$packageName" &
		rePid=$!

		wait "$rePid"

		clear
		echo ""
		echo "$packageName removed ..."
		echo ""
	fi

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

#START SERVERS AND CREATE SPLIT
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
		x)
			remove
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
