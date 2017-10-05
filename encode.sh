#!/bin/bash

die() {
    echo "$program: $1" >&2
    exit ${2:-1}
}

escape_string() {
    echo "$1" | sed "s/'/'\\\''/g;/ /s/^\(.*\)$/'\1'/"
}

readonly program="$(basename "$0")"

readonly input="$1"

if [ ! "$input" ]; then
    die 'too few arguments'
fi

handbrake="HandBrakeCLI"
mediainfo="mediainfo"

frame_rates_location="/path/to/Frame Rates"
subtitles_location="/path/to/Subtitles"

# My advice is: do NOT change these HandBrake options. I've encoded over 300
# Blu-ray Discs, 30 DVDs and numerous other files with these settings and
# they've never let me down.

handbrake_options=" --markers --large-file --encoder x264 --encopts vbv-maxrate=25000:vbv-bufsize=31250:ratetol=inf --crop 0:0:0:0 --strict-anamorphic"

width="$(mediainfo --Inform='Video;%Width%' "$input")"
height="$(mediainfo --Inform='Video;%Height%' "$input")"

if (($width > 1280)) || (($height > 720)); then
    max_bitrate="2500"
elif (($width > 720)) || (($height > 576)); then
    max_bitrate="2000"
else
    max_bitrate="1800"
fi

min_bitrate="$((max_bitrate / 2))"

bitrate="$(mediainfo --Inform='Video;%BitRate%' "$input")"

if [ ! "$bitrate" ]; then
    bitrate="$(mediainfo --Inform='General;%OverallBitRate%' "$input")"
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

frame_rate="$(mediainfo --Inform='Video;%FrameRate_Original%' "$input")"

if [ ! "$frame_rate" ]; then
    frame_rate="$(mediainfo --Inform='Video;%FrameRate%' "$input")"
fi

frame_rate_file="$(basename "$input")"
frame_rate_file="$frame_rates_location/${frame_rate_file%\.[^.]*}.txt"

if [ -f "$frame_rate_file" ]; then
    handbrake_options="$handbrake_options --rate $(cat "$frame_rate_file")"
elif [ "$frame_rate" == '29.970' ]; then
    handbrake_options="$handbrake_options --rate 23.976"
else
    handbrake_options="$handbrake_options --rate 30 --pfr"
fi

channels="$(mediainfo --Inform='Audio;%Channels%' "$input" | sed 's/[^0-9].*$//')"

if (($channels > 2)); then
    handbrake_options="$handbrake_options --aencoder ca_aac,copy:ac3"
elif [ "$(mediainfo --Inform='General;%Audio_Format_List%' "$input" | sed 's| /.*||')" == 'AAC' ]; then
    handbrake_options="$handbrake_options --aencoder copy:aac"
fi

if [ "$frame_rate" == '29.970' ]; then
    handbrake_options="$handbrake_options --detelecine"
fi

srt_file="$(basename "$input")"
srt_file="$subtitles_location/${srt_file%\.[^.]*}.srt"

if [ -f "$srt_file" ]; then
    subtitle_format="$(mediainfo --Inform='Text;%Format%' "$input" | sed q)"

    if [ "$subtitle_format" == 'VobSub' ] || [ "$subtitle_format" == 'PGS' ]; then
        handbrake_options="$handbrake_options --subtitle 1 --subtitle-burned"
    else
        tmp=""

        trap '[ "$tmp" ] && rm -rf "$tmp"' 0
        trap '[ "$tmp" ] && rm -rf "$tmp"; exit 1' SIGHUP SIGINT SIGQUIT SIGTERM

        tmp="/tmp/${program}.$$"
        mkdir -m 700 "$tmp" || exit 1

        temporary_srt_file="$tmp/subtitle.srt"
        cp "$srt_file" "$temporary_srt_file" || exit 1

        handbrake_options="$handbrake_options --srt-file $(escape_string "$temporary_srt_file") --srt-codeset UTF-8 --srt-lang eng --srt-default 1"
    fi
fi

output="${input%\.*}-converted.mp4"

echo "Encoding: $input" >&2

time "$handbrake" \
    $handbrake_options \
    --input "$input" \
    --output "$output" \
    2>&1 | tee -a "/tmp/converted"
