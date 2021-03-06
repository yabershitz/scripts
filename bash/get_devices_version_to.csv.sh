#!/bin/bash

#this script will provide a csv file with the devices and the related agent version
#the CSV format will present as the following: created_at,id,name,owner_id,platform_version,platform,serial_number
#version = 1.1
#Please fill the path to the API before running the script (only csv or txt file)
API_KEY="Path/to/the/API/Key/file"
API_ID="Path/to/the/API/ID/file"
#Sub_Org is Optional
Sub_ORG="Path/to/the/Sub/ORG/file"

if [ "$1" == "-h" ] || [ "$1" == "--help" ]; then
  echo "Usage: `basename $0` filename.csv "
  echo "scripte version 1.1"
  exit 0
fi

trap 'rm ne_expand ne_expand2 tempusers' INT

checkJq=$(which jq)
if [ -z $checkJq ]; then
	echo "please install jq before running the script"
	exit 0
else
	echo "jq path:" $checkJq
fi

if [ -z $API_ID ] || [ -z $API_ID ]; then
	echo "please edit the script and paste the path to the API_Key and API_ID files (2 first lines in the script)"
	exit 0
else
	key=$(head -n 1 $API_KEY)
	id=$(head -n 1 $API_ID)
	key=`echo $key | sed 's/\\r//g'`
	id=`echo $id | sed 's/\\r//g'`
fi

origSUB_ORG="Path/to/the/Sub/ORG/file"
if [ -z $Sub_ORG ]; then
	echo "sub org didn't configured"
else
	org=$(head -n 1 $Sub_ORG)
	org=`echo $org | sed 's/\\r//g'`
fi

#if using sub org so use different string
if [ -z $org ]; then
token=$(curl -d '{"grant_type":"client_credentials", "client_id":"'"$id"'", "client_secret":"'"$key"'"}' -H "Content-Type: application/json" -X POST https://api.metanetworks.com/v1/oauth/token | jq -r ".access_token")
else
token=$(curl -d '{"grant_type":"'"client_credentials"'", "client_id":"'"$id"'", "client_secret":"'"$key"'", "scope": "'"org:$org"'"}' -H "Content-Type: application/json" -X POST https://api.metanetworks.com/v1/oauth/token | jq -r ".access_token")
fi

#verify that the token\key\id isn't null
if [ -z $token ] || [ -z $key ] || [ -z $id ] || [ $token == null ]; then
	echo "please verify the path to API_KEY and API_ID files or the Key\ID"
	exit 0
else 
	echo "your token is:" $token
	echo "note:you can verify the token permissions and the org id by decoding the token string as base 64"
fi

curl -X GET https://api.metanetworks.com/v1/network_elements?expand=true -H "Content-Type: application/json" -H "Authorization: Bearer $token" > ne_expand

cat ne_expand | jq -r .'[] | select (.type=="Device") | select (.device_info) | .created_at,.id,.name,.owner_id,(.device_info | .agent_version,.platform,.platform_version,.serial_number)' > ne_expand2

curl -X GET https://api.metanetworks.com/v1/users -H "Content-Type: application/json" -H "Authorization: Bearer $token" > tempusers



rm ne_expand
l=0
line=0
echo "created_at,id,device name,email,family name,private name,user id,agent version,platform,platform version,serial_number(if exist)" > $1

while IFS= read -r field1; do
	((l = l+1))
	if [ $l -eq 1 ]; then  
	created_at=$field1
	continue
	fi
	if [ $l -eq 2 ]; then 
	id=$field1
	continue
	fi
	if [ $l -eq 3 ]; then 
	name=$field1
	continue
	fi
	if [ $l -eq 4 ]; then 
	owner_id=$field1
	uid=`echo $field1 | sed 's/\\r//g'`
	user=$(cat tempusers | jq -r --arg uid "$uid" .'[] | select (.id==$uid) | .email,.family_name,.given_name')
	email=$(echo $user | cut -d " " -f 1)
	fname=$(echo $user | cut -d " " -f 2)
	pname=$(echo $user | cut -d " " -f 3)
	owner_id=$email,$fname,$pname,$field1
	continue
	fi
	if [ $l -eq 5 ]; then 
	platform_version=$field1
	continue
	fi
	if [ $l -eq 6 ]; then 
	platform=$field1
	continue
	fi
	if [ $l -eq 7 ]; then 
	serial_number=$field1
	continue
	fi
	if [ $l -eq 8 ]; then
	((line = line+1))
	echo "Writing line number" $line
	str=$created_at,$id,$name,$owner_id,$platform_version,$platform,$serial_number
	echo $str >> $1
	l=0
	continue
	fi

done < ne_expand2
rm ne_expand2 tempusers


