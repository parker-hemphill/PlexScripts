#!/bin/bash
PIDFILE=~/convert.pid
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

### The directories below are required so that files can be moved along as they are converted.  Best if $media_root points to a mounted disk for Plex Server
media_root="/media/server" #this is the base directory where media files are imported from torrent/nzb client.  Also serves as holder for converted files awaiting import into Plex
# Create folder inside /media manually and chown it to the user you run Plex and torrent client with

MAKE_DIR(){ if [ ! -d "$2" ]; then mkdir "$2"; chmod "$1" "$2"; fi } # $1 sets mode for DIR 770 by default; $2 is name to check/create if it doesn't exist

CHECK_BIN(){ hash $1 2>/dev/null || { echo >&2 "$1 required but it's not installed.  Aborting."; exit 1; }; } #Checks if required binaries are installed

# Required binaries check
for i in "mediainfo" "HandBrakeCLI"
do
CHECK_BIN "$i"
done

# Loop to check for directories needed to process files.  Will create if they don't exist
if [ ! -d "$media_root" ]
then
MAKE_DIR 770 "$media_root"
MAKE_DIR 770 "$media_root/torrent" 
MAKE_DIR 770 "$media_root/torrent/Complete"
for j in "Rename" "IMPORT" "Convert"
do
  MAKE_DIR 770 "$media_root/torrent/Complete/$j"
 for i in "TVShows" "Movies"
 do
   MAKE_DIR 770 "$media_root/torrent/Complete/$j/$i"
 done
done
fi

# Find command to move only media files into the convert directory
find $media_root/torrent/Complete/TVShows/ -not -name '*sample*' -regex '.*\.\(avi\|mkv\|mod\|mp4\|m4v\)' -exec mv "{}" $media_root/torrent/Complete/Convert/TVShows \;
find $media_root/torrent/Complete/Movies/ -not -name '*sample*' -regex '.*\.\(avi\|mkv\|mod\|mp4\|m4v\)' -exec mv "{}" $media_root/torrent/Complete/Convert/Movies \;

# IFS set to new line to handle spaces in filenames
IFS=$'\n'

# Check if there are any files to convert in TV directory and then check Movies directory
if [ -n "$(ls -A $media_root/torrent/Complete/Convert/TVShows/)" ]
then
 for i in $(ls -ltr $media_root/torrent/Complete/Convert/TVShows/ | tail -1 | awk '{$1=$2=$3=$4=$5=$6=$7=$8=""; print $0}' | cut -c 9-)
 do
 handbrake_options=" --markers --large-file --encoder x264 --encopts vbv-maxrate=25000:vbv-bufsize=31250:ratetol=inf --crop 0:0:0:0 --strict-anamorphic"
 width="$(mediainfo --Inform='Video;%Width%' "$media_root/torrent/Complete/Convert/TVShows/$i")"; height="$(mediainfo --Inform='Video;%Height%' "$media_root/torrent/Complete/Convert/TVShows/$i")"
if (($width > 1280)) || (($height > 720)); then
    max_bitrate="1800"
elif (($width > 720)) || (($height > 576)); then
    max_bitrate="1500"
else
    max_bitrate="1400"
fi
min_bitrate="$((max_bitrate / 2))"
bitrate="$(mediainfo --Inform='Video;%BitRate%' "$media_root/torrent/Complete/Convert/TVShows/$i")"
if [ ! "$bitrate" ]; then
    bitrate="$(mediainfo --Inform='General;%OverallBitRate%' "$media_root/torrent/Complete/Convert/TVShows/$i")"
    bitrate="$(((bitrate / 10) * 9))"
fi
if [ "$bitrate" ]; then
    bitrate="$(((bitrate / 5) * 4))"
    bitrate="$((bitrate / 1000))"
    bitrate="$(((bitrate / 100) * 100))"
    if (($bitrate > $max_bitrate)); then
        bitrate="$max_bitrate"
    elif (($bitrate < $min_bitrate)); then
        bitrate="$min_bitrate"
    fi
    else
        bitrate="$min_bitrate"
fi
handbrake_options="$handbrake_options --vb $bitrate"
frame_rate="$(mediainfo --Inform='Video;%FrameRate_Original%' "$media_root/torrent/Complete/Convert/TVShows/$i")"
if [ ! "$frame_rate" ]; then
    frame_rate="$(mediainfo --Inform='Video;%FrameRate%' "$media_root/torrent/Complete/Convert/TVShows/$i")"
fi
    handbrake_options="$handbrake_options --rate 30 --pfr"
channels="$(mediainfo --Inform='Audio;%Channels%' "$media_root/torrent/Complete/Convert/TVShows/$i" | sed 's/[^0-9].*$//')"
if (($channels > 2)); then
    handbrake_options="$handbrake_options --aencoder ca_aac,copy:ac3"
elif [ "$(mediainfo --Inform='General;%Audio_Format_List%' "$media_root/torrent/Complete/Convert/TVShows/$i" | sed 's| /.*||')" == 'AAC' ]; then
    handbrake_options="$handbrake_options --aencoder copy:aac"
fi

if [ "$frame_rate" == '29.970' ]; then
    handbrake_options="$handbrake_options --detelecine"
fi
echo "Encoding: $i" >&2
HandBrakeCLI $handbrake_options --input="$media_root/torrent/Complete/Convert/TVShows/${i}" --output="$media_root/torrent/Complete/Convert/TVShows/${i%\.*}-converted.mp4" 2>&1 | tee -a "/tmp/converted"
cat /dev/null > /tmp/converted
  mv "$media_root/torrent/Complete/Convert/TVShows/${i%\.*}-converted.mp4" "/media/server/torrent/Complete/Rename/TVShows/" &&  rm -f "$media_root/torrent/Complete/Convert/TVShows/${i}" || rm "$media_root/torrent/Complete/Convert/TVShows/${i%\.*}-converted.mp4"
  filebot -script fn:amc --output "/media/server/torrent/Complete/IMPORT" --action move -non-strict "/media/server/torrent/Complete/Rename/TVShows" --log-file amc.log --def excludeList=amc.txt --def clean=yes
 done
elif [ -n "$(ls -A $media_root/torrent/Complete/Convert/Movies/)" ]
then
 for i in $(ls -ltr $media_root/torrent/Complete/Convert/Movies/ | tail -1 | awk '{$1=$2=$3=$4=$5=$6=$7=$8=""; print $0}' | cut -c 9-)
 do
 handbrake_options=" --markers --large-file --encoder x264 --encopts vbv-maxrate=25000:vbv-bufsize=31250:ratetol=inf --crop 0:0:0:0 --strict-anamorphic"
 width="$(mediainfo --Inform='Video;%Width%' "$media_root/torrent/Complete/Convert/Movies/$i")"; height="$(mediainfo --Inform='Video;%Height%' "$media_root/torrent/Complete/Convert/Movies/$i"$
if (($width > 1280)) || (($height > 720)); then
    max_bitrate="1800"
elif (($width > 720)) || (($height > 576)); then
    max_bitrate="1500"
else
    max_bitrate="1400"
fi
min_bitrate="$((max_bitrate / 2))"
bitrate="$(mediainfo --Inform='Video;%BitRate%' "$media_root/torrent/Complete/Convert/Movies/$i")"
if [ ! "$bitrate" ]; then
    bitrate="$(mediainfo --Inform='General;%OverallBitRate%' "$media_root/torrent/Complete/Convert/Movies/$i")"
    bitrate="$(((bitrate / 10) * 9))"
fi
if [ "$bitrate" ]; then
    bitrate="$(((bitrate / 5) * 4))"
    bitrate="$((bitrate / 1000))"
    bitrate="$(((bitrate / 100) * 100))"
    if (($bitrate > $max_bitrate)); then
        bitrate="$max_bitrate"
    elif (($bitrate < $min_bitrate)); then
        bitrate="$min_bitrate"
    fi
    else
        bitrate="$min_bitrate"
fi
handbrake_options="$handbrake_options --vb $bitrate"
frame_rate="$(mediainfo --Inform='Video;%FrameRate_Original%' "$media_root/torrent/Complete/Convert/Movies/$i")"
if [ ! "$frame_rate" ]; then
    frame_rate="$(mediainfo --Inform='Video;%FrameRate%' "$media_root/torrent/Complete/Convert/Movies/$i")"
fi
    handbrake_options="$handbrake_options --rate 30 --pfr"
channels="$(mediainfo --Inform='Audio;%Channels%' "$media_root/torrent/Complete/Convert/Movies/$i" | sed 's/[^0-9].*$//')"
if (($channels > 2)); then
    handbrake_options="$handbrake_options --aencoder ca_aac,copy:ac3"
elif [ "$(mediainfo --Inform='General;%Audio_Format_List%' "$media_root/torrent/Complete/Convert/Movies/$i" | sed 's| /.*||')" == 'AAC' ]; then
    handbrake_options="$handbrake_options --aencoder copy:aac"
fi
if [ "$frame_rate" == '29.970' ]; then
    handbrake_options="$handbrake_options --detelecine"
fi
echo "Encoding: $i" >&2
HandBrakeCLI $handbrake_options --input="$media_root/torrent/Complete/Convert/Movies/${i}" --output="$media_root/torrent/Complete/Convert/Movies/${i%\.*}-converted.mp4" 2>&1 | tee -a "/tmp/converted"
cat /dev/null > /tmp/converted
  mv "$media_root/torrent/Complete/Convert/Movies/${i%\.*}-converted.mp4" "/media/server/torrent/Complete/Rename/Movies/" &&  rm -f "$media_root/torrent/Complete/Convert/Movies/${i}" || rm "$media_root/torrent/Complete/Convert/Movies/${i%\.*}-converted.mp4"
  filebot -script fn:amc --output "/media/server" --action move -non-strict "/media/server/torrent/Complete/Rename/Movies" --log-file amc.log --def excludeList=amc.txt --def clean=yes
 done
else
echo "No files to encode"
fi
rm $PIDFILE
