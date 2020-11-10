#!/bin/bash

function get_ui_token() {
  local username=$1
  local password=$2

  echo $(curl --header "Content-Type: application/x-www-form-urlencoded" \
              --request POST \
              --data "grant_type=password&username=$username&password=$password" \
              --user "ui:uiman" \
              ${RP_URL}/uat/sso/oauth/token | \
              jq '.access_token' --raw-output)

}

function get_api_token() {
  local ui_token=$1

  local api_token="$(curl --header "Authorization: Bearer $ui_token" \
                          --request GET \
                          ${RP_URL}/uat/sso/me/apitoken | \
                          jq ".access_token" --raw-output)"

  if [[ "$api_token"="null" ]]
  then
    echo $(curl --header "Authorization: Bearer $ui_token" \
                --request POST \
                ${RP_URL}/uat/sso/me/apitoken | \
                jq ".access_token" --raw-output)
  else
    echo ${api_token}
  fi
}

function import_xunit() {
    local project=$1
    local api_token=$2
    local file=$3

    echo $(curl --header "Content-Type: multipart/form-data" \
        --header "Authorization: Bearer $api_token" \
        --request POST \
        --form "file=@./$file" \
        ${RP_URL}/api/v1/${project}/launch/import)
}

USERNAME=$1
PASSWORD=$2
PROJECT=$3
FILE=$4

RP_URL="http://reportportal.infrastructure.testing-farm.io"
TMP_FILE="output.xml"
ZIP_NAME=$(grep "BASEOS_CI_COMPONENT=" ${FILE} | head -n 1 | cut -d'"' -f2)

python3 standardize_xunit.py $FILE $ZIP_NAME > $TMP_FILE

zip -r $ZIP_NAME.zip $TMP_FILE
ZIP_FILE=$ZIP_NAME.zip

UI_TOKEN=$(get_ui_token ${USERNAME} ${PASSWORD})

API_TOKEN=$(get_api_token ${UI_TOKEN})

IMPORT=$(import_xunit ${PROJECT} ${API_TOKEN} ${ZIP_FILE})
echo $IMPORT

rm $ZIP_FILE $TMP_FILE

