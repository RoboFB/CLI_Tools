#!/bin/bash
program="$1"
allowed_raw="$2"

if [[ ! -f "$program" ]]; then
    echo "Error: '$program' not found or not a file."
    exit 1
fi

# Use default allowed functions for "philo"
if [[ "$allowed_raw" == "philo" ]]; then
    allowed_raw="memset, printf, malloc, free, write, usleep, gettimeofday, pthread_create, pthread_detach, pthread_join, pthread_mutex_init, pthread_mutex_destroy, pthread_mutex_lock, pthread_mutex_unlock"
fi

# Convert allowed list into regex pattern (e.g., "memset|printf|...")
# allowed_pattern
allowed_pattern=$(echo "$allowed_raw" | tr -d '\n' | sed 's/, */|/g' | sed 's/|$//')

nm -u "$program" | cut -c2- | sort -u | grep -Ev "$allowed_pattern"
echo ""
