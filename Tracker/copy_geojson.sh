#!/bin/bash
# Script to copy GeoJSON files from parent project to Tracker assets

cd "$(dirname "$0")/.."

# Create directories if they don't exist
mkdir -p Tracker/assets/ski_resorts/palarinsal
mkdir -p Tracker/assets/ski_resorts/3valley
mkdir -p Tracker/assets/ski_resorts/morzine
mkdir -p Tracker/assets/ski_resorts/beidahu

# Copy GeoJSON files
for resort in palarinsal 3valley morzine beidahu; do
  if [ -f "assets/$resort/runs.geojson" ]; then
    cp "assets/$resort/runs.geojson" "Tracker/assets/ski_resorts/$resort/"
    echo "Copied runs.geojson for $resort"
  fi
  if [ -f "assets/$resort/lifts.geojson" ]; then
    cp "assets/$resort/lifts.geojson" "Tracker/assets/ski_resorts/$resort/"
    echo "Copied lifts.geojson for $resort"
  fi
done

echo "Done!"
ls -la Tracker/assets/ski_resorts/*/

