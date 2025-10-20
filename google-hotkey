#!/bin/bash


# Get the highlighted text directly from primary selection
search_text=$(xclip -o -selection primary)

# URL encode the text for Google search
encoded_text=$(echo "$search_text" | sed 's/ /+/g' | sed 's/[^a-zA-Z0-9+]//g')

# Open Google search in default browser
xdg-open "https://www.google.com/search?q=$encoded_text" &