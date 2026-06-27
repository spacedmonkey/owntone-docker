#!/bin/bash

# 1. Ensure the FIFO pipe exists
if [ ! -p /srv/pipes/audio-input ]; then
    mkfifo /srv/pipes/audio-input
fi

# 2. Keep the pipe open in the background to prevent SIGPIPE
exec 3<> /srv/pipes/audio-input

# 3. Optimized pipeline for real-time ALSA processing
/usr/bin/ffmpeg \
  -f alsa \
  -thread_queue_size 1024 \
  -use_wallclock_as_timestamps 1 \
  -ac 1 \
  -i plughw:1,0 \
  -f s16le \
  -acodec pcm_s16le \
  -ar 48000 \
  - \
| /usr/bin/sox -t raw -r 48000 -e signed -b 16 -c 1 - -t raw - \
  silence 1 0.1 1% 1 10.0 1% \
> /srv/pipes/audio-input
