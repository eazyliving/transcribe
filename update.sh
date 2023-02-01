#!/bin/bash

#
# Check the installation for updates
#

if [[ $(git diff --stat) != '' ]]; then
	echo "updating transcription git"
	git pull origin master
fi

cd whisper.cpp

if [[ $(git diff --stat) != '' ]]; then
	echo "updating whisper.cpp"
	git pull origin master
	make all
fi
