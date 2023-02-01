#!/bin/bash

#
# Check the installation for updates
#

# transcribe itself
git pull origin 


# whisper.cpp
cd whisper.cpp
git pull origin
make 2>/dev/null >/dev/null
