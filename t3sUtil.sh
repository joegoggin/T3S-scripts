#!/bin/bash

#VARIABLES
handleKeys=1
isStart=1
scriptDir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
configDir="$HOME/.config/t3s"
configFile="$configDir/util.conf"

#OPTS
while getopts :d:w:p: flags; do
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
function createConfig {
	cp $scriptDir/defaultConfig/util.conf ~/.config/t3s/util.conf
}

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
	echo "-- Hit 'l' to log into Expo CLI"
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
	docker compose up -d

	while ! docker ps --format '{{.Names}}' | grep -q "$webContainerName"; do
		sleep 1
	done

	tmux split-window -h -d "echo ''; echo 'starting native server ...'; echo ''; docker attach $nativeContainerName" &

	clear
	printOpts

	docker logs -f "$webContainerName" &

	sleep 5

	if [ "$isStart" -eq 1 ]; then
		eval "$browserOpenCMD http://localhost:$prismaPort"
		eval "$browserOpenCMD http://localhost:$webPort"
		isStart=0
	fi
}

function stopServer {
	clear
	echo "Stopping and removing remaining containers ..."
	echo ""
	docker compose down
	echo ""

	echo ""
	echo "Done ... All containers stopped and removed!"
	echo ""
}

function restartServer {
	clear
	echo ""
	echo "Restarting Live Servers ..."
	echo ""

	docker compose restart

	clear

	tmux split-window -h -d "docker attach $nativeContainerName" &
	tmux send-keys -t 2 c

	printOpts
	docker logs -f "$webContainerName" &

}

function installAll {
	clear
	echo ""
	echo "Installing Packages ..."
	echo ""

	docker exec "$webContainerName" sh -c "yarn"
	docker exec "$nativeContainerName" sh -c "yarn"
	docker exec "$prismaContainerName" sh -c "yarn"

	clear
	echo ""
	echo "Packages installed ..."
	echo ""

	restartServer
}

function setInstallInfoByKey {
	case "$key" in
	1)
		installDir="apps/expo"
		installContainer="$nativeContainerName"
		;;
	2)
		installDir="apps/next"
		installContainer="$webContainerName"
		;;
	3)
		installDir="packages/app"
		installContainer="$webContainerName"
		;;
	4)
		installDir="packages/server"
		installContainer="$webContainerName"
		;;
	5)
		installDir="packages/db"
		installContainer="$prismaContainerName"
		;;
	6)
		if [ -d "$projectDir/packages/email" ]; then
			installDir="packages/email"
		fi
		;;
	esac
}

function search {
	searchOutputFile=$(mktemp)

	docker exec "$webContainerName" sh -c "npm search $packageName" >"$searchOutputFile"

	searchOutput=$(cat "$searchOutputFile")

	searchResult=$(echo "$searchOutput" | head -n 2 | tail -n 1 | awk '{print $1}')

	rm -rf "$searchOutputFile"
}

function installNew {
	handleKeys=0

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

	setInstallInfoByKey

	echo ""
	echo "Installing $packageName ..."
	echo ""

	if [[ "$isDev" == 'y' || "$isDev" == 'Y' ]]; then
		docker exec "$installContainer" sh -c "cd $installDir && yarn add -D $packageName"
	else
		docker exec "$installContainer" sh -c "cd $installDir && yarn add $packageName"
	fi

	clear
	echo ""
	echo "$packageName installed ..."
	echo ""

	restartServer
	handleKeys=1
}

function remove {
	handleKeys=0

	clear
	echo ""
	read -rp "Enter the name of the package: " packageName

	echo ""
	echo "Where is the package installed?"
	printLocations

	read -rsn 1 key

	setInstallInfoByKey

	removePackage=1

	while true; do
		cd "$installDir" || throwDirError "$installDir"

		dependencies=$(jq -r '.dependencies | keys_unsorted[]' package.json)
		devDependencies=$(jq -r '.devDependencies | keys_unsorted[]' package.json)

		if (
			echo "$dependencies"
			echo "$devDependencies"
		) | grep -q "$packageName"; then
			restart=1
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

				setInstallInfoByKey
			else
				removePackage=0
				restart=0
				clear
				break
			fi

		fi
	done

	if [ "$removePackage" -eq 1 ]; then
		docker exec "$installContainer" sh -c "cd $installDir && yarn remove $packageName"

		clear
		echo ""
		echo "$packageName removed ..."
		echo ""
	fi

	cd "$projectDir" || throwDirError "$projectDir"

	if [ "$restart" -eq 1 ]; then
		restartServer
	else
		printOpts
		docker logs -f "$webContainerName" &
	fi
	handleKeys=1
}

function expoLogin {
	tmux send-keys -t 2 C-p C-q
	tmux split-window -h "docker exec -it $nativeContainerName npx expo login"

	while tmux list-panes -F "#{pane_index}" | grep -q 2; do
		sleep 1
	done

	docker compose restart native
	tmux split-window -h -d "docker attach milo-native"
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

# HANDLE CONFIG
mkdir -p "$configDir" || exit 1

[[ -f "$configFile" ]] || createConfig
source "$configFile"
webContainerName="$(basename $projectDir)-web"
nativeContainerName="$(basename $projectDir)-native"
postgresContainerName="$(basename $projectDir)-postgres"
prismaContainerName="$(basename $projectDir)-prisma-studio"

#START SERVERS AND CREATE SPLIT
docker compose build
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
		l)
			expoLogin
			;;
		q)
			stopServer
			break
			;;
		esac
	fi
done
