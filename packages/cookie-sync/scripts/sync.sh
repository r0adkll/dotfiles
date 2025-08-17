#!/bin/bash

# This script is used to synchronize files between /mnt/cookie-jar and /mnt/gdrive/cookie-jar.
# It uses rsync to copy files and directories, using an intermediary cache directory.

set -e  # Exit on any error

# Define source, intermediary, and destination directories
SOURCE_DIR="/mnt/cookie-jar/printing"
CACHE_DIR="/mnt/cache/cookie-crumbs/printing"
DEST_DIR="/mnt/gdrive/cookie-jar/printing"

# Check if source directory exists
if [ ! -d "$SOURCE_DIR" ]; then
    echo "Error: Source directory $SOURCE_DIR does not exist"
    exit 1
fi

# Check if cache directory mount is available
if [ ! -d "/mnt/cache" ]; then
    echo "Error: Cache directory /mnt/cache is not mounted"
    exit 1
fi

# Check if Google Drive mount is available
if [ ! -d "/mnt/gdrive" ]; then
    echo "Error: Google Drive is not mounted at /mnt/gdrive"
    exit 1
fi

# Create intermediary and destination directories if they don't exist
mkdir -p "$CACHE_DIR"
mkdir -p "$DEST_DIR"

echo "Starting two-stage sync process..."
echo "Stage 1: $SOURCE_DIR -> $CACHE_DIR"
echo "Stage 2: $CACHE_DIR -> $DEST_DIR"

# Stage 1: Sync from source to cache (intermediary)
echo "=== Stage 1: Syncing to cache directory ==="
rsync -avh \
    --progress \
    --delete \
    --exclude='*.tmp' \
    --exclude='*.log' \
    --exclude='.DS_Store' \
    --exclude='Thumbs.db' \
    "$SOURCE_DIR/" \
    "$CACHE_DIR/"

echo "Stage 1 completed successfully!"
echo "Cache size: $(du -sh "$CACHE_DIR" 2>/dev/null | cut -f1)"

# Stage 2: Sync from cache to Google Drive
echo ""
echo "=== Stage 2: Syncing to Google Drive ==="
rsync -avh \
    --progress \
    --delete \
    --exclude='*.tmp' \
    --exclude='*.log' \
    --exclude='.DS_Store' \
    --exclude='Thumbs.db' \
    "$CACHE_DIR/" \
    "$DEST_DIR/"

echo "Stage 2 completed successfully!"

# Show final summary
echo ""
echo "=== Sync Summary ==="
echo "Source: $SOURCE_DIR"
echo "Cache: $CACHE_DIR ($(du -sh "$CACHE_DIR" 2>/dev/null | cut -f1))"
echo "Destination: $DEST_DIR ($(du -sh "$DEST_DIR" 2>/dev/null | cut -f1))"
echo "Two-stage sync completed successfully!"
