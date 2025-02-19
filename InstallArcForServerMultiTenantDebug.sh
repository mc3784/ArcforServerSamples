#!/bin/bash

cloudEnv="AzureCloud"

# Get the username of the user who invoked sudo
user=$(logname)

# Add the environment variable to the user's .bashrc file
sudo -u $user bash -c 'echo "export MSFT_ARC_TEST=\"true\"" >> $HOME/.bashrc'

# Source the .bashrc file to apply the changes
sudo -u $user bash -c 'source $HOME/.bashrc'