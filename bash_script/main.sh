#!/bin/bash

source auth_client.sh
source import_client.sh

USERNAME=$1
PASSWORD=$2
PROJECT=$3
FILE=$4

TMP_FILE="output.xml"
ZIP_NAME=$(grep "BASEOS_CI_COMPONENT=" ${FILE} | head -n 1 | cut -d'"' -f2)

python3 ../standardize_xunit.py $FILE $ZIP_NAME > $TMP_FILE

zip -r $ZIP_NAME.zip $TMP_FILE
ZIP_FILE=$ZIP_NAME.zip

UI_TOKEN=$(get_ui_token ${USERNAME} ${PASSWORD})

API_TOKEN=$(get_api_token ${UI_TOKEN})

IMPORT=$(import_xunit ${PROJECT} ${API_TOKEN} ${ZIP_FILE})
echo $IMPORT

rm $ZIP_FILE $TMP_FILE

