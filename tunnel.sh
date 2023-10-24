#!/bin/bash

#VARIABLES
PORT=3000

#OPTS
while getopts :p:e: FLAGS; do
	case $FLAGS in
	e)
		ENV_FILE=$OPTARG
		;;
	p)
		PORT=$OPTARG
		;;
	?)
		echo "Error: -$OPTARG is not an option"
		;;
	esac
done

#FUNCTIONS
function startTunnel {
	if [ -z "$LT_PID" ]; then
		echo ""

		LT_OUTPUT_FILE=$(mktemp)

		ngrok http "$PORT" --log=stdout >"$LT_OUTPUT_FILE" &
		LT_PID=$!

		while ! grep -q "started tunnel" "$LT_OUTPUT_FILE"; do
			sleep 1
		done

		URL=$(grep "msg=\"started tunnel\"" "$LT_OUTPUT_FILE" | sed 's/.*url=//')

		if [ -n "$ENV_FILE" ]; then
			NEW_LINE="const tunnel = \"$URL\";"

			sed -i "3c$NEW_LINE" "$ENV_FILE"

			echo "Url copied to $ENV_FILE ..."
			echo ""
		fi

		echo "your url is: $URL"
		echo ""
		echo "Tunnel running on port $PORT ..."
		echo ""
		echo "-- Hit 'r' to restart tunnel"
		echo "-- Hit 'q' to quit"
		echo ""
	fi

	rm -rf "$LT_OUTPUT_FILE"
}

function stopTunnel {
	if [ -n "$LT_PID" ]; then
		kill "$LT_PID"
		wait "$LT_PID"
		LT_PID=""
	fi
}

function restartTunnel {
	stopTunnel

	echo ""
	echo "Restarting tunnel .."
	echo ""

	startTunnel
}

#START PROGRAM
startTunnel

#HANDLE KEY EVENTS
while :; do
	read -rsn 1 key

	case "$key" in
	r)
		restartTunnel
		;;
	q)
		stopTunnel
		break
		;;
	esac
done
