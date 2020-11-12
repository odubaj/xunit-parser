#!/bin/bash

#TODO
#treba ziskat info o scratch-buildoch a buidoch cez taskinfo -> brew taskinfo -v <task-id> + brew buildinfo <nvr> -> mas tu aj meno aj verziu, release, len to rozparsuj pekne
#poriesit userov a ich prihlasovanie cez curl
#poriesit jednotlive baliky aby boli ich vysledky importnute do spravnych projektov
#success rate opravit
#email server nastavit
#containery su nejake divne co sa tyka nvr a build_id

# get UI authentification token
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

# get API authentification token
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

# import XML file to ReportPortal
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

RP_URL="http://localhost:8080" #"http://reportportal.infrastructure.testing-farm.io"
TMP_FILE="output.xml"
TASKINFO_FILE="taskinfo.txt"

# get data from TestingFarm Xunit
TASK_ID=$(grep "property name=\"baseosci.artifact-id\" value=" ${FILE} | cut -d'"' -f4)
ZIP_NAME=$(grep "BASEOS_CI_COMPONENT=" ${FILE} | head -n 1 | cut -d'"' -f2)

# get data about the task from brew
brew taskinfo -v $TASK_ID > $TASKINFO_FILE
NVR=$(grep "Build: " $TASKINFO_FILE | cut -d' ' -f2)
BUILD_ID=$(grep "Build: " $TASKINFO_FILE | cut -d' ' -f3 | tr -d '()')

ZIP_FILE=$ZIP_NAME.zip

# resolve scratch builds
if [ -z $BUILD_ID ] || [ -z $NVR ]
then
  ZIP_FILE=$ZIP_NAME-scratch.zip
  if [ -z $BUILD_ID ]
  then
    BUILD_ID="scratch"
  fi

  if [ -z $NVR ]
  then
    NVR="scatch"
  fi
fi

# create custom Xunit for ReportPortal
python3 standardize_xunit.py $FILE $ZIP_NAME $NVR $BUILD_ID > $TMP_FILE

zip -r $ZIP_FILE $TMP_FILE

# import data with appropriate tokens
UI_TOKEN=$(get_ui_token ${USERNAME} ${PASSWORD})

API_TOKEN=$(get_api_token ${UI_TOKEN})

IMPORT=$(import_xunit ${PROJECT} ${API_TOKEN} ${ZIP_FILE})
echo $IMPORT

rm $ZIP_FILE $TMP_FILE $TASKINFO_FILE

