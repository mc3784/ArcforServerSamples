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

export MSFT_ARC_TEST=true
sudo systemctl stop walinuxagent
sudo systemctl disable walinuxagent

sudo ufw --force enable
sudo ufw deny out from any to 169.254.169.254
sudo ufw default allow incoming

# Install the hybrid agent
bash /tmp/install_linux_azcmagent.sh;
if [ $? -ne 0 ]; then
  exit 1
fi

export subscriptionId=$subscriptionID;
export resourceGroup=$resourceGroupName;
export tenantId=$TENANT_ID;
export location=$resourceLocation;
export authType="token";
export correlationId="b4975a09-15b5-4e8a-be6c-322c4eef7dad";
export cloud="AzureCloud";


# Download the installation package
LINUX_INSTALL_SCRIPT="/tmp/install_linux_azcmagent.sh"
if [ -f "$LINUX_INSTALL_SCRIPT" ]; then rm -f "$LINUX_INSTALL_SCRIPT"; fi;
output=$(wget https://gbl.his.arc.azure.com/azcmagent-linux -O "$LINUX_INSTALL_SCRIPT" 2>&1);
if [ $? != 0 ]; then wget -qO- --method=PUT --body-data="{\"subscriptionId\":\"$subscriptionId\",\"resourceGroup\":\"$resourceGroup\",\"tenantId\":\"$tenantId\",\"location\":\"$location\",\"correlationId\":\"$correlationId\",\"authType\":\"$authType\",\"operation\":\"onboarding\",\"messageType\":\"DownloadScriptFailed\",\"message\":\"$output\"}" "https://gbl.his.arc.azure.com/log" &> /dev/null || true; fi;
echo "$output";

# Install the hybrid agent
bash "$LINUX_INSTALL_SCRIPT";

# Run connect command
sudo azcmagent connect --resource-group "$resourceGroup" --tenant-id "$tenantId" --location "$location" --subscription-id "$subscriptionId" --cloud "$cloud" --correlation-id "$correlationId";