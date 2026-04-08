#!/usr/bin/env zsh

mkdir -p out/Linux_Speed

# Note: icon resource (resources/icon.rc) is Windows-only, skipped on Linux
odin build src -o:speed -out:out/Linux_Speed/HollowsEngine

echo "Current working directory: $(pwd)"

if [[ $? -eq 0 ]]; then
    cp -r assets out/Linux_Speed/assets
    ./out/Linux_Speed/HollowsEngine
fi
