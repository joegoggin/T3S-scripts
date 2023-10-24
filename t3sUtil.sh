#!/bin/bash

#VARAIABLES
HANDLE_KEYS=1

#OPTS
while getopts :d:p: FLAGS; do
	case $FLAGS in
	d)
		PROJECT_DIR=$OPTARG
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
	if [ -z "$WEB_PID" ]; then
		printOpts

		yarn web &

		while true; do
			PID=$(lsof -i :3000 | awk '$2 == "PID" {next} {print $2; exit}')
			if [ -n "$PID" ]; then
				WEB_PID="$PID"
				break
			fi
			sleep 1
		done
	fi
}

function stopServer {
	if [ -n "$WEB_PID" ]; then
		kill "$WEB_PID"

		while ps -p "$WEB_PID" >/dev/null; do
			sleep 1
		done

		WEB_PID=""
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
	YARN_PID=$!

	wait "$YARN_PID"

	clear
	echo ""
	echo "Packages installed ..."
	echo ""
	startServer
}

function installNew {
	HANDLE_KEYS=0
	stopServer

	echo ""
	read -rp "Enter the name of the package: " PACKAGE_NAME

	echo ""
	read -rp "Is the package a dev dependency? y/n: " IS_DEV

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
		cd "$PROJECT_DIR/apps/expo" || throwDirError "$PROJECT_DIR/apps/expo"
		;;
	2)
		cd "$PROJECT_DIR/apps/next" || throwDirError "$PROJECT_DIR/apps/next"
		;;
	3)
		cd "$PROJECT_DIR/packages/app" || throwDirError "$PROJECT_DIR/packages/app"
		;;
	4)
		cd "$PROJECT_DIR/packages/server" || throwDirError "$PROJECT_DIR/packages/server"
		;;
	5)
		cd "$PROJECT_DIR/packages/db" || throwDirError "$PROJECT_DIR/packages/db"
		;;
	esac

	echo ""
	echo "Installing $PACKAGE_NAME ..."
	echo ""

	if [[ "$IS_DEV" == 'y' || "$IS_DEV" == 'Y' ]]; then
		yarn add -D "$PACKAGE_NAME" &
		YARN_PID=$!
	else
		yarn add "$PACKAGE_NAME" &
		YARN_PID=$!
	fi

	wait "$YARN_PID"

	clear
	echo ""
	echo "$PACKAGE_NAME installed ..."
	echo ""

	cd "$PROJECT_DIR" || throwDirError "$PROJECT_DIR"
	startServer
	HANDLE_KEYS=1
}

#CHANGE TO PROJECT DIRECTORY
if [ -z "$PROJECT_DIR" ]; then
	echo ""
	echo "Error: Project directory required."
	echo ""
	echo "You can enter a project directory by using the -d flag."
	echo ""
	echo "Example: webServer -d ~/Projects/projectName"
	echo ""
	exit 1
fi

cd "$PROJECT_DIR" || throwDirError "$PROJECT_DIR"

#START WEB SERVER
startServer

#HANDLE KEY EVENTS
while :; do
	if [ "$HANDLE_KEYS" -eq 1 ]; then
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
