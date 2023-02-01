#!/bin/bash

#
# Check the installation for updates
#

# transcribe itself
git pull origin master


# whisper.cpp
cd whisper.cpp
git pull origin master
make all
