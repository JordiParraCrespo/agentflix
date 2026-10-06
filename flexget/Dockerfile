FROM python:3.12-slim

# ffmpeg + mediainfo are used by sort-media.sh to fix audio for Chromecast.
RUN apt-get update \
    && apt-get install -y --no-install-recommends ffmpeg mediainfo gosu \
    && rm -rf /var/lib/apt/lists/*

RUN pip install --no-cache-dir flexget transmission-rpc

COPY sort-media.sh entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/sort-media.sh /usr/local/bin/entrypoint.sh

ENTRYPOINT ["entrypoint.sh"]
