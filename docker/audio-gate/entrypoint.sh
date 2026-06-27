#!/bin/bash

if [ ! -p /srv/pipes/audio-input ]; then
    mkfifo /srv/pipes/audio-input
fi
exec 3<> /srv/pipes/audio-input

# CHANGED: -ac 1 -> -ac 2 (FFmpeg) and -c 1 -> -c 2 (SoX)
/usr/bin/ffmpeg \
  -f alsa \
  -thread_queue_size 1024 \
  -use_wallclock_as_timestamps 1 \
  -ac 2 \
  -i plughw:1,0 \
  -f s16le \
  -acodec pcm_s16le \
  -ar 44100 \
  - \
| /usr/bin/sox -t raw -r 44100 -e signed -b 16 -c 2 - -t raw - \
  silence 1 0.1 1% 1 10.0 1% \
> /srv/pipes/audio-input
