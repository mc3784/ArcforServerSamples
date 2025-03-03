#!/bin/bash
principalId="$2"
if [ -z "$principalId" ]; then
  echo "Error: principalId is required."
  exit 1
fi

get_machine_details() {
  principalId=$1

  # Get token
  token_response=$(curl -s -H "Metadata:true" "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&object_id=$principalId&resource=$AZUREURI")
  access_token=$(echo "$token_response" | jq -r '.access_token')

  if [ -z "$access_token" ]; then
    echo "Failed to retrieve access token" >&2
    return 1
  fi

  # Get machine details
  metadata_response=$(curl -s -H "Metadata:true" "http://169.254.169.254/metadata/instance?api-version=2021-02-01")
  resourceId=$(echo "$metadata_response" | jq -r '.compute.resourceId')
  resourceLocation=$(echo "$metadata_response" | jq -r '.compute.location')

  if [ -z "$resourceId" ] || [ -z "$resourceLocation" ]; then
    echo "Failed to retrieve machine details" >&2
    return 1
  fi

  IFS='/' read -r -a resourceIdArray <<< "$resourceId"
  subscriptionID=${resourceIdArray[2]}
  resourceGroupName=${resourceIdArray[4]}

  echo "$access_token,$subscriptionID,$resourceGroupName,$resourceLocation"
}

machine_info=$(get_machine_details "$principalId")