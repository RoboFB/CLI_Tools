#!/bin/bash

# Script to connect to Soundcore Q20i Bluetooth device

# Get device MAC address

DEVICE_NAME="soundcore\|q20i"

bluetoothctl power on
bluetoothctl discoverable on
bluetoothctl -t 3 scan on
DEVICE_MAC=$(bluetoothctl devices | grep -i $DEVICE_NAME | cut -d' ' -f2 | head -1)
if [ -z "$DEVICE_MAC" ]; then
	echo "Soundcore device not found in paired devices."
	exit 1
fi

echo "Found device: $DEVICE_MAC"

# Check if already connected
if bluetoothctl info "$DEVICE_MAC" | grep -q "Connected: yes"; then
    echo "Device is connected. Disconnecting and removing..."
    bluetoothctl disconnect "$DEVICE_MAC"
    sleep 1
    bluetoothctl remove "$DEVICE_MAC"
    echo "✓ Device disconnected and removed!"
else
    echo "Connecting to $DEVICE_NAME..."
    
    bluetoothctl connect "$DEVICE_MAC"
    
    # Check connection status
    if bluetoothctl info "$DEVICE_MAC" | grep -q "Connected: yes"; then
        echo "✓ Successfully connected to $DEVICE_NAME device!"
		xdg-open "https://music.youtube.com/" 2>/dev/null & # Open YouTube Music in default browser can be removed if not needed
    else
        echo "✗ Failed to connect. Device may not be in pairing mode or not found."
    fi
fi

