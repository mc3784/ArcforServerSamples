#!/bin/bash

cloudEnv="AzureCloud"
principalId=""

while getopts "c:p:" opt; do
  case $opt in
    c) cloudEnv="$OPTARG"
    ;;
    p) principalId="$OPTARG"
    ;;
    \?) echo "Invalid option -$OPTARG" >&2
    ;;
  esac
done

if [ -z "$principalId" ]; then
  echo "Error: principalId is required."
  exit 1
fi