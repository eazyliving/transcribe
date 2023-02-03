#!/bin/bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
cd $SCRIPT_DIR

if [ -f ./fyyd.cfg ]
	then
		source "./fyyd.cfg"
fi

if [ -f ./.rates.txt ]
	then
		rm -f ./.rates.txt
fi

export LC_NUMERIC="en_US.UTF-8"

# Check ffmpeg etc

if ! command -v ffmpeg &> /dev/null
then
	echo "Can't find ffmpeg. Please install."
    exit
fi

if ! command -v git &> /dev/null
then
	echo "Can't find git. Please install."
    exit
fi

if ! command -v curl &> /dev/null
then
	echo "Can't find curl. Please install."
    exit
fi

if ! command -v jq &> /dev/null
then
	echo "Can't find jq. Please install."
    exit
fi

if ! command -v bc &> /dev/null
then
	echo "Can't find bc. Please install."
    exit
fi


if [ ! -f "whisper.cpp/whisper.cpp" ]
	then
		echo "downloading whisper.cpp"
		git clone https://github.com/ggerganov/whisper.cpp	
		
		echo "compiling whisper..."
		cd whisper.cpp
		make
		
		echo "downloading the model"
		./models/download-ggml-model.sh medium	
	else
		cd whisper.cpp
fi

THREADS=0
THREADS=`getconf _NPROCESSORS_ONLN`
if [ $? -ne 0 ] 
	then
		THREADS=`getconf NPROCESSORS_ONLN`
fi


if [ $THREADS -eq 0 ]
	then
		echo -n "could not find number of threads. how many to use for transcription? (number or return to let whisper utilize cpu as guessed): "
	else
		echo -n "maximum of $THREADS threads found. how many to use for transcription? (number of threads or return for $THREADS) : "
fi

read inputthreads
	
if [ ! -z "$inputthreads" ]
	then
		THREADS=$inputthreads
fi		

THREAD_OPT=""

if [ "$THREADS" -ne 0 ]
	then
		THREAD_OPT=" -t $THREADS"
fi

if [ -z "$ACCESSTOKEN" ]
	then
		echo -n "please provide the accesstoken for fyyd (return to set later in fyyd.cfg): "
		read token_input
		if [ ! -z "$token_input" ]
			then
				ACCESSTOKEN=$token_input
		fi
fi

START=`date +%s`

echo -e "\nstarting test. this might take some minutes, please wait...\n"
nice -n 18 ./main -m models/ggml-medium.bin $THREAD_OPT -l de ../test.wav 2>/dev/null

if [ $? -ne 0 ]
	then
		echo "error transcribing. stopping"
		
fi


DURATION=300
END=`date +%s`
TOOK=$(($END-$START))
RATE=`echo "$DURATION/$TOOK" | bc -l`

echo -e "------------------------------------------------------------------------------------------------------\n"

echo -n "transcription took $TOOK seconds for 300 seconds audio. that is "
printf "%.2f" $(echo "$DURATION/$TOOK" | bc -l)
echo " times faster than realtime audio."

if (( $(echo "$RATE < 1.5" |bc -l) ))
	then
		echo "that's very slow and you should maybe NOT transcribe with this computer."
	elif (( $(echo "$RATE < 2" |bc -l) ))
	then
		echo "that's ok, but you should raise the number of threads if possible."
	else
		echo "that's great. let's transcribe some podcasts!"
fi

echo "Please remember: This thread was running with very low priority. Maybe you were watching a video or doing something else that consumed a lot of power. So maybe this rate does not reflect the actual performance of this machine."
echo
cd ..

rm -f fyyd.cfg
echo "THREADS=$THREADS" >> ./fyyd.cfg
echo "ATOKEN=$ACCESSTOKEN" >> ./fyyd.cfg
echo "PIDFILE=~/.fyyd-transcribe.pid" >> ./fyyd.cfg
echo "MODEL=medium" >> ./fyyd.cfg
