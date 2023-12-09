#!/bin/bash

#VARIABLES
scriptDir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
configDir="$HOME/.config/t3s"
configFile="$configDir/prisma.conf"
startContainer=1
message=""

#OPTS
while getopts :d:wp: flags; do
	case $flags in
	d)
		projectDir=$OPTARG
		prismaContainerName="$(basename $projectDir)-prisma-studio"
		webContainerName="$(basename $projectDir)-web"
		nativeContainerName="$(basename $projectDir)-native"
		;;
	p)
		port=$OPTARG
		;;
	w)
		startContainer=0
		;;
	?)
		echo "Error: -$OPTARG is not an option"
		;;
	esac
done

#CHANGE TO PRISMA DIRECTORY
if [ -z "$projectDir" ]; then
	echo ""
	echo "Error: Project directory required."
	echo ""
	echo "You can enter a primsa directory by using the -d flag."
	echo ""
	echo "Example: prismaTool -d ~/Projects/projectName/packages/db"
	echo ""
	exit 1
fi

cd "$projectDir" || {
	echo ""
	echo "Error: $projectDir is not a directory."
	echo ""
	exit 1
}

#FUNCTIONS
function createConfig {
	cp $scriptDir/defaultConfig/prisma.conf ~/.config/t3s/prisma.conf
}

function printOpts {
	echo ""
	echo "-- Hit 'r' to restart Prisma Studio"
	echo "-- Hit 'p' to push changes to db"
	echo "-- Hit 'g' to generate Prisma client"
	echo "-- Hit 'q' to quit"
	echo ""
}

function displayMessage {
	while ! docker ps --format '{{.Names}}' | grep -wq "$prismaContainerName"; do
		sleep 1
	done

	clear

	if [ "$message" != "" ]; then
		echo ""
		echo "$message"
		echo ""
	fi

	echo ""
	echo "Prisma Studio running on port $port ..."
	printOpts

	message=""
}

function startDev {
	if [ "$startContainer" -eq 1 ]; then
		echo ""
		echo "Starting Prisma Studio ..."
		echo ""

		docker compose up -d --build prisma-studio
	else
		echo ""
		echo "Waiting for Prisma Studio to Start ..."
		echo ""
	fi

	displayMessage
}

function stopDev {
	echo ""
	echo "Stopping and Removing Prisma Studio Container..."
	echo ""

	docker compose down prisma-studio

	echo ""
	echo "Done ... Container Stopped and Removed!"
	echo ""
}

function restartDev {
	clear

	echo ""
	echo "Restarting Primsa Studio ..."
	echo ""

	docker compose restart prisma-studio

	displayMessage
}

function push {
	clear

	echo ""
	echo "Pushing changes to the DB ..."
	echo ""

	docker exec -it "$prismaContainerName" sh -c "cd packages/db && yarn db:push"

	message="Done ... Changes pushed to DB and Prisma client genterated!"
	generate
}

function generate {
	echo ""
	echo "Generating Prisma client for Web and Native ..."
	echo ""

	docker exec "$webContainerName" sh -c "cd packages/db && yarn db:generate"
	docker exec "$nativeContainerName" sh -c "cd packages/db && yarn db:generate"

	if [ -z "$message" ]; then
		message="Done ... Prisma client generated!"
	fi

	displayMessage
}

#HANDLE CONFIG
mkdir -p "$configDir" || exit 1

[[ -f "$configFile" ]] || createConfig
source "$configFile"

#START PROGRAM
startDev

#HANDLE KEY EVENTS
while :; do
	read -rsn 1 key

	if [ -z "$projectDir" ]; then
		break
	fi

	case "$key" in
	r)
		restartDev
		;;
	p)
		push
		;;
	g)
		generate
		;;
	q)
		stopDev
		break
		;;
	esac
done
