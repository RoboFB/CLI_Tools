#!/bin/bash

find src -type f -name "*.c" | awk -F/ '{sub(/^src\//, "", $0); print "\t\t" $0 " \\"}'
