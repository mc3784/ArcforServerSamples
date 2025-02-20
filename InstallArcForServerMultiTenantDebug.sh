#!/bin/bash
export MSFT_ARC_TEST=true

if [ -z "$MSFT_ARC_TEST" ]; then
  echo "Error: MSFT_ARC_TEST is not set."
  exit 1
fi
