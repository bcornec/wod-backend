#!/bin/bash
# Cleanup all students dir
clear

#ASK FOR RANGE: Starting number and ending number separated by a space
startrange=0
endrange=0

while [[ $startrange -eq 0 || $endrange -eq 0 || $startrange -gt $endrange ]]
do
        echo "Please provide range for user: starting and ending separated by a space:"
        read startrange endrange
done

echo "Range from $startrange to $endrange"

echo "This script will empty home folders of students from $startrange to $endrange"

source $HOME/jupyter-procmail/scripts/procmail-action.sh

for stdid in $(seq $startrange $endrange); do 
	stddir="/student/student$stdid"
	erase_student
done
