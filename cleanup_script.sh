#!/bin/bash

# Cleanup script removing logs older than 30 days

find . -type d -regextype sed -ctime +30 -regex '\.\/.[0-9]*$' -exec rm -rf {} \;