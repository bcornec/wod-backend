#!/bin/bash

set -e
set -u
set -o pipefail

echo "Installing a Workshop on Demand environment"

# redirect stdout/stderr to a file
mkdir -p $HOME/.jupyter
exec &> >(tee $HOME/.jupyter/install.log)

export woddistrib=`grep -E '^ID=' /etc/os-release | cut -d= -f2 | sed 's/"//g'`-`grep -E '^VERSION_ID=' /etc/os-release | cut -d= -f2 | sed 's/"//g'`

# Get path of execution
EXEPATH=`dirname "$0"`
EXEPATH=`( cd "$EXEPATH" && pwd )`

# Call the distribution specific install script
echo "Installing $woddistrib specificities"
$EXEPATH/install-$woddistrib.sh

# Call the common install script to finish install
echo "Installing common remaining stuff"
$EXEPATH/install-common.sh