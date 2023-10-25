#!/bin/bash

#VARIABLES
port=3000

#OPTS
while getopts :p:e: flags; do
	case $flags in
	e)
		envFile=$OPTARG
		;;
	p)
		port=$OPTARG
		;;
	?)
		echo "Error: -$OPTARG is not an option"
		;;
	esac
done

#FUNCTIONS
function startTunnel {
	if [ -z "$ltPid" ]; then
		echo ""

		ltOutputFile=$(mktemp)

		ngrok http "$port" --log=stdout >"$ltOutputFile" &
		ltPid=$!

		while ! grep -q "started tunnel" "$ltOutputFile"; do
			sleep 1
		done

		url=$(grep "msg=\"started tunnel\"" "$ltOutputFile" | sed 's/.*url=//')

		if [ -n "$envFile" ]; then
			newLine="const tunnel = \"$url\";"

			sed -i "3c$newLine" "$envFile"

			echo "Url copied to $envFile ..."
			echo ""
		fi

		clear
		echo ""
		echo "your url is: $url"
		echo ""
		echo "Tunnel running on port $port ..."
		echo ""
		echo "-- Hit 'r' to restart tunnel"
		echo "-- Hit 'q' to quit"
		echo ""
	fi

	rm -rf "$ltOutputFile"
}

function stopTunnel {
	if [ -n "$ltPid" ]; then
		kill "$ltPid"
		wait "$ltPid"
		ltPid=""
	fi
}

function restartTunnel {
	stopTunnel

	clear
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
	*) ;;
	esac
done
