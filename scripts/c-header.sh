#!/bin/bash


awk '/ auto/ { exit } { print }' include/$(NAME).h > tmp-auto-header.h
echo '// auto' >> tmp-auto-header.h
awk '/^[a-zA-Z_][a-zA-Z0-9_ \*\t]*\([^\)]*\)[ \t]*$$/ { \
	last=$$0; \
	getline; \
	if ($$0 ~ /^\s*\{/) { \
		split(last, a, /[ \t]+/); \
		if (a[1] == "int") sub(/[ \t]+/, "\t\t\t", last); \
		else sub(/[ \t]+/, "\t\t", last); \
		print last ";"; \
	} \
}' $(shell find $(DIR_SRC) -type f -name '*.c') | grep -v static >> tmp-auto-header.h
echo "\n#endif" >> tmp-auto-header.h
cmp -s tmp-auto-header.h include/$(NAME).h || mv tmp-auto-header.h include/$(NAME).h
rm -f tmp-auto-header.h

