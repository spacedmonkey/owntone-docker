#!/bin/bash

# Ensure the FIFO pipe exists
if [ ! -p /srv/pipes/audio-input ]; then
    mkfifo /srv/pipes/audio-input
fi

# CHANGED: plughw:0,0 -> plughw:1,0
/usr/bin/ffmpeg -f alsa -ac 1 -i plughw:1,0 -f s16le -acodec pcm_s16le -ar 44100 - \
| /usr/bin/sox -t raw -r 44100 -e signed -b 16 -c 1 - -t raw - \
  silence 1 0.1 1% 1 10.0 1% \
> /srv/pipes/audio-input
