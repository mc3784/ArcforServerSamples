#!/bin/bash

cloudEnv="AzureCloud"

# Get the username of the user who invoked sudo, or fall back to the current user
user=${SUDO_USER:-$(whoami)}

# Add the environment variable to the user's .bashrc file
sudo -u $user bash -c 'echo "export MSFT_ARC_TEST=\"true\"" >> $HOME/.bashrc'

# Source the .bashrc file to apply the changes
sudo -u $user bash -c 'source $HOME/.bashrc'