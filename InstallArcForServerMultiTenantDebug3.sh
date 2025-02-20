#!/bin/bash
export MSFT_ARC_TEST=true

if [ -z "$MSFT_ARC_TEST" ]; then
  echo "Error: MSFT_ARC_TEST is not set."
  exit 1
fi

principalId="$2"

if [ -z "$principalId" ]; then
  echo "Error: principalId is required."
  exit 1
fi


sudo systemctl stop walinuxagent
sudo systemctl disable walinuxagent

sudo ufw --force enable
sudo ufw deny out from any to 169.254.169.254
#sudo ufw default allow incoming #This never completes. Commenting it

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

IFS=',' read -r access_token subscriptionID resourceGroupName resourceLocation <<< "$machine_info"
export ACCESS_TOKEN=$access_token
export SUBSCRIPTION_ID=$subscriptionID
export RESOURCE_GROUP=$resourceGroupName
export LOCATION=$resourceLocation

# Download the installation package
retryCount=5
while [ $retryCount -gt 0 ]; do
  output=$(wget https://gbl.his.arc.azure.com/azcmagent-linux -O /tmp/install_linux_azcmagent.sh 2>&1);
  if [ $? != 0 ]; then wget -qO- --method=PUT --body-data="{\"subscriptionId\":\"$subscriptionId\",\"resourceGroup\":\"$resourceGroup\",\"tenantId\":\"$tenantId\",\"location\":\"$location\",\"correlationId\":\"$correlationId\",\"authType\":\"$authType\",\"operation\":\"onboarding\",\"messageType\":\"DownloadScriptFailed\",\"message\":\"$output\"}" "https://gbl.his.arc.azure.com/log" &> /dev/null || true; fi;
  echo "$output";
  if [ $? -eq 0 ]; then
    break
  else
    echo "Error downloading installation package. Retrying in $sleepSeconds seconds..."
    sleep $sleepSeconds
    retryCount=$((retryCount-1))
  fi
done

# Install the hybrid agent
bash /tmp/install_linux_azcmagent.sh;
if [ $? -ne 0 ]; then
  exit 1
fi

# Run connect command
retryCount=3
while [ $retryCount -gt 0 ]; do
  sudo azcmagent connect --resource-group "$RESOURCE_GROUP" --tenant-id "$TENANT_ID" --location "$LOCATION" --subscription-id "$SUBSCRIPTION_ID" --cloud "$CLOUD" --correlation-id "$CORRELATION_ID" --access-token "$ACCESS_TOKEN";
  if [ $? -eq 0 ]; then
    break
  else
    echo "Error connecting agent. Retrying..."
    retryCount=$((retryCount-1))