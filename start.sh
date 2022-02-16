#!/bin/sh

while [ : ]
do
    bash /netlify-ddns.sh $NETLIFY_TOKEN $NETLIFY_DOMAIN $NETLIFY_SUBDOMAIN $NETLIFY_TTL &
    PROGRAM_PID=$!
    wait "${PROGRAM_PID}"
    sleep 5m
done
