#!/bin/bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
PB_PID=""

RED='\033[0;31m'
NOCOLOR='\033[0m'
GREEN='\033[0;32m'

export LC_NUMERIC="en_US.UTF-8"

if [ -f ./fyyd.cfg ]
	then
		source "./fyyd.cfg"
	else
		echo "no config found. please run setup.sh first."
		exit 0
fi

if [ -z $ATOKEN  ]
	then
		echo "Please get an accesstoken first. Visit https://fyyd.de/dev/app/ to create one."
		exit 0;
fi

trap ctrl_c INT
trap stop EXIT

function ETASTRING {
	
	TETA="$1"
	if [ "$(uname -s)" == "Darwin" ]
		then
			echo -n `date -u -r ${TETA#-} +%T`
		else
			echo -n `date -d@${TETA} -u +%T`
	fi


}

function stop {
	rm -f $PIDFILE
	if [ ! -z $PB_PID  ]
		then
			kill $PB_PID
			wait $PB_PID 2>/dev/null
	fi
}

function ctrl_c() {

	if [ ! -z $PB_PID  ]
		then
			kill $PB_PID
			wait $PB_PID 2>/dev/null
			PB_PID=""
	fi
	echo "------------------------------"
	echo "STOPPING... sending notification to fyyd"
	echo "bye bye"
	echo "------------------------------"
	
	curl -H "Authorization: Bearer $ATOKEN" "https://api.fyyd.de/0.2/transcribe/error/$ID" -d "error=0"
	rm -f $PIDFILE
	exit 
}

progress() {
	
	if [ -z $PB_PID ]
		then
			while :
			do
				
				SECONDSGONE=$((SECONDSGONE+1))
				
				LINE=$(tail -1 ./redir.txt)
				if [ -z "$LINE" ]
					then
						
						# no output by whisper so far...
					
						echo -n "."
						LASTLINE=""
						LASTRATE=0
						sleep 1
						continue
				fi
				
				if [ -z "$LASTLINE" ]
					then
						echo
				fi
				
				if [ "$LINE" = "$LASTLINE" ]
					then
						# no new output, just count down
						ETA=$((ETA-1))
					else
					
						# it did smth! calculate new rate and estimate the remaining time :)
						
						STAMP=$(echo ${LINE} | awk 'BEGIN { FS="[ ]" } ; { print $3 }')
						IFS=: read -r h m s <<<"${STAMP:0:8}"
						h=${h#0};m=${m#0};s=${s#0}
					
						WHERE=$(((h * 60 + m) * 60 + s))
						
						if [ $WHERE -eq 0 ]
							then
								THISRATE=1
							else
								THISRATE=$(echo "$WHERE/$SECONDSGONE" | bc -l)
						fi	
				
						ETA=$(echo "$DURATION/$THISRATE - $SECONDSGONE" | bc -l)
						
				fi
								
				ETA=$(printf "%.0f" "$ETA")
		
				if [ "$LINE" = "$LASTLINE" ]
					then
						printf "\rETA: "
					else
						printf "\r\033[KETA: "
				
				fi

				ETASTRING "$ETA"
					
				if (( $(echo "$THISRATE > $LASTRATE" |bc -l) ))
					then
						COLOR=$GREEN
				elif (( $(echo "$THISRATE < $LASTRATE" |bc -l) ))
					then
						COLOR=$RED
					else
						COLOR=$NOCOLOR
				fi

				printf " ($COLOR%.1fx$NOCOLOR)" $THISRATE
				
				if [ "$LINE" = "$LASTLINE" ]
					then
						echo -n
					else
						echo -n " ${LINE:0:$(tput cols)-30}"
				fi

				LASTLINE="$LINE"
				LASTRATE=$THISRATE
				sleep 1
		
			done  & 2>/dev/null
			PB_PID=$!
		else
			kill $PB_PID
			wait $PB_PID 2>/dev/null
			PB_PID=""
	fi
	
}

pid() {
	if [ -f $PIDFILE ]
	then
	  PID=$(cat $PIDFILE)
	  ps -p $PID > /dev/null 2>&1
	  if [ $? -eq 0 ]
	  then
		echo "Process already running"
		exit 1
	  else
		## Process not found assume not running
		echo $$ > $PIDFILE
		if [ $? -ne 0 ]
		then
		  echo "Could not create PID file"
		  exit 1
		fi
	  fi
	else
	  echo $$ > $PIDFILE
	  if [ $? -ne 0 ]
	  then
		echo "Could not create PID file"
		exit 1
	  fi
	fi
}

pid

echo "Checking for updates"

./update.sh
	
echo "Starting engines! Let's transcribe some episodes!"
cd whisper.cpp

while :
do

	#------------------------------------------------------------------------------------
	# get data for one episode to transcribe from fyyd.de
	#------------------------------------------------------------------------------------
	
	ID=""
	
	echo "getting data from fyyd"
	DATA=`echo $(curl -s -H "Authorization: Bearer $ATOKEN"  "https://api.fyyd.de/0.2/transcribe/next")`

	eval "$(echo $DATA |jq -r '.data | to_entries | .[] | .key + "=" + (.value | @sh)')"	

	# exit if nothing to do

	if [ -z $ID  ]
		then
			echo "nothing to transcribe. exit!"
			exit 0;
	fi
	
	#------------------------------------------------------------------------------------
	# download episode 
	#------------------------------------------------------------------------------------
	
	echo "starting download of episode $ID, \"$TITLE\", duration $DURATION seconds ($(ETASTRING $DURATION))"

	curl -s -L "${URL}" > $TOKEN
	if [ $? -ne 0 ]
		then
			echo "error downloading"
			curl -H "Authorization: Bearer $ATOKEN" "https://api.fyyd.de/0.2/transcribe/error/$ID" -d "error=10"
			continue
		
	fi
	
	
	#------------------------------------------------------------------------------------
	# convert whatever was donwloaded to 16kHz WAV 
	#------------------------------------------------------------------------------------
	
	echo "converting to wav"

	ffmpeg -y -i $TOKEN -acodec pcm_s16le -ac 1 -ar 16000 $TOKEN.wav >/dev/null  2>/dev/null
	
	if [ $? -eq 1 ]
		then
			echo "error converting to wav"
			curl -H "Authorization: Bearer $ATOKEN" "https://api.fyyd.de/0.2/transcribe/error/$ID" -d "error=11"
			continue
	fi

	rm $TOKEN
	
	#------------------------------------------------------------------------------------
	# transcribe wav to vtt
	#------------------------------------------------------------------------------------

	if [ ${LANG} == "null" ]
		then
			LANG="auto"
	fi
	 
	echo -n "loading model"

	# start process to display guessed remaining time
	
	SECONDSGONE=0
	LASTLINE=""
	progress

	nice -n 18 ./main -m models/ggml-$MODEL.bin -t $THREADS -l $LANG -ovtt $TOKEN.wav >./redir.txt 2>/dev/null

	if [ $? -ne 0 ]
		then
			echo "error transcribing"
			curl -H "Authorization: Bearer $ATOKEN" "https://api.fyyd.de/0.2/transcribe/error/$ID" -d "error=12"
			progress
			printf "\b"
			continue
	fi
	
	progress
	echo
	echo "finished transcription in $(ETASTRING $SECONDSGONE)"


	#------------------------------------------------------------------------------------
	# push transcript to fyyd
	#------------------------------------------------------------------------------------
	
	echo "sending transcript to fyyd"
	curl -H "Authorization: Bearer $ATOKEN" "https://api.fyyd.de/0.2/transcribe/set/$ID" --data-binary @$TOKEN.wav.vtt
	rm $TOKEN.wav
	rm $TOKEN.wav.vtt
	
	if [ -f ~/.fyyd-stop ]; then
		rm ~/.fyyd-stop
		echo "stopping hard"
		exit
	fi

	echo "--------------------------------------------------------------"
	sleep 2
done

rm $PIDFILE
