#!/bin/bash

source functions.sh

USERNAME=$1
PASSWORD=$2
ZIP_NAME=$3
SCRATCH=$4
TASK_ID=$5
TEST_PLAN_NAME=$6

# resolve correct project
PROJECT=$(get_project ${ZIP_NAME})

if [ $SCRATCH == "true" ]
then
  ZIP_NAME=$ZIP_NAME-scratch.zip
fi

# import data with appropriate tokens
UI_TOKEN=$(get_ui_token ${USERNAME} ${PASSWORD})

API_TOKEN=$(get_api_token ${UI_TOKEN})
echo $API_TOKEN

#find launch with same task-id
FOUND=$(get_launch_by_task_id ${PROJECT} ${API_TOKEN} ${TASK_ID})
echo $FOUND
number_to_merge=$(echo $FOUND | jq '.page.totalElements' --raw-output)
found_launch_id=$(echo $FOUND | jq '.content[0].id' --raw-output)
found_launch_uuid=$(echo $FOUND | jq '.content[0].uuid' --raw-output)

if [ $number_to_merge != 0 ]
then
  #find running item to be stopped
  RUNNING_ITEM=$(get_item_by_filter ${PROJECT} ${API_TOKEN} ${TASK_ID} ${TEST_PLAN_NAME} ${found_launch_id})
  echo $RUNNING_ITEM
  number_of_items=$(echo $RUNNING_ITEM | jq '.page.totalElements' --raw-output)

  if [ $number_of_items != 0 ]
  then
    item_id=$(echo $RUNNING_ITEM | jq '.content[0].id' --raw-output)
    item_uuid=$(get_item_uuid ${PROJECT} ${API_TOKEN} ${item_id} | jq '.[0].uuid' --raw-output)
    result=$(stop_error_item ${PROJECT} ${API_TOKEN} ${found_launch_uuid} ${item_uuid})
    echo $result
  fi
  
fi