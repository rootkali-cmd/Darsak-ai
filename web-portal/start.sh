#!/bin/bash
cd "$(dirname "$0")/.next/standalone"
cp -r "$(dirname "$0")/public" .
PORT=3000 setsid node server.js &>/tmp/darsak-web.log &
echo "Server started on port 3000 (PID: $!)"
