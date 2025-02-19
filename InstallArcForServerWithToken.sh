#!/bin/bash

cloudEnv="AzureCloud"
principalId="$2"

echo 'export MSFT_ARC_TEST="true"' >> ~/.bashrc
source ~/.bashrc