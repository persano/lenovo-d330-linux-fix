#!/usr/bin/env bash
# Lenovo IdeaPad D330-10IGL Camera Bridge Daemon
# Bridges raw IPU3 libcamera streams to V4L2 loopback devices (/dev/video10, /dev/video11)
# Ensures compatibility with Chromium, Firefox, Zoom, and Cheese

set -euo pipefail

CAMERA_INDEX="${1:-0}"
LOOPBACK_DEV="${2:-/dev/video10}"
WIDTH="${3:-1280}"
HEIGHT="${4:-720}"
FPS="${5:-30}"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [d330-camera-bridge] $*"
}

if ! command -v gst-launch-1.0 >/dev/null 2>&1; then
    log "Error: GStreamer 1.0 (gst-launch-1.0) is required for camera streaming."
    exit 1
fi

if [[ ! -e "$LOOPBACK_DEV" ]]; then
    log "Device $LOOPBACK_DEV not found. Loading v4l2loopback module..."
    modprobe v4l2loopback exclusive_caps=1,1 card_label="D330 Front Camera (OV2680)","D330 Rear Camera (OV5648)" video_nr=10,11 max_buffers=4 || true
fi

log "Starting camera stream: camera-name index $CAMERA_INDEX -> $LOOPBACK_DEV (${WIDTH}x${HEIGHT} @ ${FPS}fps)"

# Stream from libcamerasrc via GStreamer to v4l2sink
exec gst-launch-1.0 libcamerasrc camera-name="$(libcamera-hello --list-cameras 2>/dev/null | grep -E '^([0-9]+):' | sed -n "$((CAMERA_INDEX + 1))p" | awk '{print $2}')" ! \
    video/x-raw,width="$WIDTH",height="$HEIGHT",framerate="$FPS/1" ! \
    videoconvert ! \
    video/x-raw,format=YUY2 ! \
    v4l2sink device="$LOOPBACK_DEV" sync=false
