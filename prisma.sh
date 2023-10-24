#!/bin/bash

#VARIABLES
PORT=5556

#OPTS
while getopts :d:p: FLAGS; do
	case $FLAGS in
	d)
		PRISMA_DIR=$OPTARG
		;;
	p)
		PORT=$OPTARG
		;;
	?)
		echo "Error: -$OPTARG is not an option"
		;;
	esac
done

#CHANGE TO PRISMA DIRECTORY
if [ -z "$PRISMA_DIR" ]; then
	echo ""
	echo "Error: Prisma directory required."
	echo ""
	echo "You can enter a primsa directory by using the -d flag."
	echo ""
	echo "Example: prismaTool -d ~/Projects/projectName/packages/db"
	echo ""
	exit 1
fi

cd "$PRISMA_DIR" || {
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
	if [ -z "$DEV_PID" ]; then
		DEV_OUTPUT_FILE=$(mktemp)

		yarn dev --port "$PORT" >"$DEV_OUTPUT_FILE" &
		DEV_PID=$!

		while ! grep -q "Prisma Studio is up" "$DEV_OUTPUT_FILE"; do
			sleep 1
		done

		echo ""
		echo "Prisma Studio running on port $PORT ..."
		printOpts

		rm -rf "$DEV_OUTPUT_FILE"
	fi

}

function stopDev {
	if [ -n "$DEV_PID" ]; then
		kill "$DEV_PID"
		wait "$DEV_PID"
		DEV_PID=""
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
	PUSH_PID=$!

	wait "$PUSH_PID"
	printOpts

	PUSH_PID=""
}

function generate {
	yarn db:generate &
	GEN_PID=$!

	wait "$GEN_PID"
	printOpts

	GEN_PID=""
}

#START PROGRAM
startDev

#HANDLE KEY EVENTS
while :; do
	read -rsn 1 key

	if [ -z "$PRISMA_DIR" ]; then
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
