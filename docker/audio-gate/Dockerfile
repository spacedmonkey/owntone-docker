FROM alpine:latest

# Install ffmpeg, sox, and bash
RUN apk add --no-cache ffmpeg sox bash alsa-utils

# Create a directory for the named pipe
RUN mkdir -p /srv/pipes

# Copy our startup script into the container
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Run the script
ENTRYPOINT ["/entrypoint.sh"]
