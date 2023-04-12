#!/bin/bash
#
# This is a Bash script to update a Netlify subdomain A record with the current external IP.
#
# Repo: https://github.com/skylerwlewis/netlify-ddns
# Gist: https://gist.github.com/skylerwlewis/ba052db5fe26424255674931d43fc030
#
# Usage:
# netlify-ddns.sh <ACCESS_TOKEN> <DOMAIN> <SUBDOMAIN> <TTL> [<CACHED_IP_FILE>]
#
# The example below would update the local.example.com A record to the current external IP with a TTL of 5 minutes.
# The last parameter for the script is optional and is used to cache the Netlify IP to reduce API calls.
#
# Example:
# netlify-ddns.sh aCcEsStOKeN example.com local 300 /home/johnsmith/cached-ip-file.txt
#
if [ "$#" -lt 4 ] || [ "$#" -gt 5 ]; then
  echo "Wrong number of parameters passed"
  echo "Usage:"
  echo "$0 <ACCESS_TOKEN> <DOMAIN> <SUBDOMAIN> <TTL> [<CACHED_IP_FILE>]"
  exit
fi

ACCESS_TOKEN="$1"
DOMAIN="$2"
SUBDOMAIN="$3"
TTL="$4"

if [ "$#" -ge 5 ]; then
  CACHED_IP_FILE="$5"
fi

NETLIFY_API="https://api.netlify.com/api/v1"
IP_PATTERN='^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$'

EXTERNAL_IP=`dig +short myip.opendns.com @resolver1.opendns.com`
if [[ ! $EXTERNAL_IP =~ $IP_PATTERN ]]; then
  echo "There was a problem resolving the external IP, response was \"$EXTERNAL_IP\""
  exit
fi

if [ -n "$CACHED_IP_FILE" ]; then 
  if [[ -f "$CACHED_IP_FILE" ]]; then
    if [[ $(< "$CACHED_IP_FILE") = "$EXTERNAL_IP" ]]; then
      exit
    fi
  fi
fi

DNS_ZONES_RESPONSE=`curl -s -w "\n%{http_code}" "$NETLIFY_API/dns_zones?access_token=$ACCESS_TOKEN" --header "Content-Type:application/json"`
DNS_ZONES_RESPONSE_CODE=$(tail -n1 <<< "$DNS_ZONES_RESPONSE")
DNS_ZONES_CONTENT=$(sed '$ d' <<< "$DNS_ZONES_RESPONSE")
if [[ $DNS_ZONES_RESPONSE_CODE != 200 ]]; then
  echo "There was a problem retrieving the DNS zones, response code was $DNS_ZONES_RESPONSE_CODE, response body was:"
  echo "$DNS_ZONES_CONTENT"
  exit
fi

ZONE_ID=`echo $DNS_ZONES_CONTENT | jq ".[]  | select(.name == \"$DOMAIN\") | .id" --raw-output`

DNS_RECORDS_RESPONSE=`curl -s -w "\n%{http_code}" "$NETLIFY_API/dns_zones/$ZONE_ID/dns_records?access_token=$ACCESS_TOKEN" --header "Content-Type:application/json"`
DNS_RECORDS_RESPONSE_CODE=$(awk '/./{line=$0} END{print line}' <<< "$DNS_RECORDS_RESPONSE")
DNS_RECORDS_CONTENT=$(sed '$ d' <<< "$DNS_RECORDS_RESPONSE")
if [[ $DNS_RECORDS_RESPONSE_CODE != 200 ]]; then
  echo "There was a problem retrieving the DNS records for zone \"$ZONE_ID\", response code was $DNS_RECORDS_RESPONSE_CODE, response body was:"
  echo "$DNS_RECORDS_CONTENT"
  exit
fi

HOSTNAME="$SUBDOMAIN.$DOMAIN"
RECORD=`echo $DNS_RECORDS_CONTENT | jq ".[]  | select(.hostname == \"$HOSTNAME\")" --raw-output `
RECORD_VALUE=`echo $RECORD | jq ".id" --raw-output`

## declare an array variable
declare -a array=($(echo $RECORD_VALUE))

# get length of an array
arraylength=${#array[@]}

# use for loop to read all values and indexes
for (( i=0; i<${arraylength}; i++ ));
do
  echo "index: $i, value: ${array[$i]}"
    echo "Deleting current entry for $HOSTNAME"
    RECORD_ID=`echo $RECORD | jq ".id" --raw-output`
    DELETE_RESPONSE_CODE=`curl -X DELETE -s -w "%{http_code}" "$NETLIFY_API/dns_zones/$ZONE_ID/dns_records/${array[$i]}?access_token=$ACCESS_TOKEN" --header "Content-Type:application/json"`

    if [[ $DELETE_RESPONSE_CODE != 204 ]]; then
    echo "There was a problem deleting the existing $HOSTNAME entry, response code was $DELETE_RESPONSE_CODE"
    exit
    fi
    echo "Deleted entry for $HOSTNAME with ID ${array[$i]}"
done

