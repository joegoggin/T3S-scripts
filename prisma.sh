#!/bin/bash

#VARIABLES
port=5556

#OPTS
while getopts :d:p: flags; do
	case $flags in
	d)
		prismaDir=$OPTARG
		;;
	p)
		port=$OPTARG
		;;
	?)
		echo "Error: -$OPTARG is not an option"
		;;
	esac
done

#CHANGE TO PRISMA DIRECTORY
if [ -z "$prismaDir" ]; then
	echo ""
	echo "Error: Prisma directory required."
	echo ""
	echo "You can enter a primsa directory by using the -d flag."
	echo ""
	echo "Example: prismaTool -d ~/Projects/projectName/packages/db"
	echo ""
	exit 1
fi

cd "$prismaDir" || {
	echo ""
	echo "Error: $PRISMA_DIR is not a directory."
	echo ""
	exit 1
}

#FUNCTIONS
function printOpts {
	echo ""
	echo "-- Hit 'r' to restart Prisma Studio"
	echo "-- Hit 'p' to push changes to db"
	echo "-- Hit 'g' to generate Prisma client"
	echo "-- Hit 'q' to quit"
	echo ""
}

function startDev {
	if [ -z "$devPid" ]; then
		devOutputFile=$(mktemp)

		yarn dev --port "$port" >"$devOutputFile" &
		devPid=$!

		while ! grep -q "Prisma Studio is up" "$devOutputFile"; do
			sleep 1
		done

		echo ""
		echo "Prisma Studio running on port $port ..."
		printOpts

		rm -rf "$devOutputFile"
	fi

}

function stopDev {
	if [ -n "$devPid" ]; then
		kill "$devPid"
		wait "$devPid"
		devPid=""
	fi
}

function restartDev {
	stopDev

	echo ""
	echo "Restarting Primsa Studio ..."
	echo ""

	startDev
}

function push {
	yarn db:push &
	pushPid=$!

	wait "$pushPid"
	printOpts

	pushPid=""
}

function generate {
	yarn db:generate &
	genPid=$!

	wait "$genPid"
	printOpts

	genPid=""
}

#START PROGRAM
startDev

#HANDLE KEY EVENTS
while :; do
	read -rsn 1 key

	if [ -z "$prismaDir" ]; then
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
