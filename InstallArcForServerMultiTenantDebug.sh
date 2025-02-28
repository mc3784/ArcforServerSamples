#!/bin/bash
principalId="$2"
if [ -z "$principalId" ]; then
  echo "Error: principalId is required."
  exit 1
fi

get_machine_details() {
  local principalId=$1

  # get token
  content=$(curl -s -H "Metadata:true" "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&object_id=$principalId&resource=$AZUREURI")
  access_token=$(echo $content | jq -r '.access_token')

  # machine details
  content=$(curl -s -H "Metadata:true" "http://169.254.169.254/metadata/instance?api-version=2021-02-01")
  resourceId=$(echo $content | jq -r '.compute.resourceId')
  resourceLocation=$(echo $content | jq -r '.compute.location')
  IFS='/' read -r -a resourceIdArray <<< "$resourceId"
  subscriptionID=${resourceIdArray[2]}
  resourceGroupName=${resourceIdArray[4]}

  echo "$access_token,$subscriptionID,$resourceGroupName,$resourceLocation"
}


retryCount=5
sleepSeconds=3

export TENANT_ID="72f988bf-86f1-41af-91ab-2d7cd011db47"
export AUTH_TYPE="principal"
export CORRELATION_ID="c0a82881-305f-4243-b9e3-96861a595b7e"
export CLOUD="AzureCloud"
export AZUREURI="https://management.azure.com/"
export HCRPURI="https://aka.ms/azcmagent-windows"

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