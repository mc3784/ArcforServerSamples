#!/bin/bash
principalId="$2"
if [ -z "$principalId" ]; then
  echo "Error: principalId is required."
  exit 1
fi

export AZUREURI="https://management.azure.com/"

get_machine_details() {
  local principalId=$1

  # get token
  content=$(curl -s -H "Metadata:true" "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&object_id=$principalId&resource=$AZUREURI")
  access_token=$(echo $content | jq -r '.access_token')

  # decode token to get tenantId
 tenantId=$(echo $access_token | cut -d '.' -f2 | sed 's/\-/+/g; s/_/\//g' | awk '{ len=length($0) % 4; if (len == 2) { print $0"=="; } else if (len == 3) { print $0"="; } else { print $0; } }' | base64 --decode | jq -r '.tid')

  # machine details
  content=$(curl -s -H "Metadata:true" "http://169.254.169.254/metadata/instance?api-version=2021-02-01")
  resourceId=$(echo $content | jq -r '.compute.resourceId')
  location=$(echo $content | jq -r '.compute.location')
  imageOffer=$(echo $content | jq -r '.compute.storageProfile.imageReference.offer')
  IFS='/' read -r -a resourceIdArray <<< "$resourceId"
  subscriptionId=${resourceIdArray[2]}
  resourceGroup=${resourceIdArray[4]}
  
  echo "$access_token,$tenantId,$subscriptionId,$resourceGroup,$location,$imageOffer"
}

retryCount=5
sleepSeconds=3
while [ $retryCount -gt 0 ]; do
  machine_info=$(get_machine_details "$principalId")
  if [ $? -eq 0 ]; then
    break
  else
    echo "Error getting machine details. Retrying in $sleepSeconds seconds..."
    sleep $sleepSeconds
    retryCount=$((retryCount-1))
  fi
done


IFS=',' read -r access_token tenantId subscriptionId resourceGroup location imageOffer <<< "$machine_info"