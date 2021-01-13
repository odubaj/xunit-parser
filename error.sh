#!/bin/bash

source functions.sh

USERNAME=$1
PASSWORD=$2
ZIP_NAME=$3
SCRATCH=$4
TASK_ID=$5
TEST_PLAN_NAME=$6
log1=$7
log2=$8
log3=$9
REPORT_LOG="report.log"

echo " topic ERROR - starting script for task $TASK_ID and plan $TEST_PLAN_NAME" >> $TASK_ID/$REPORT_LOG
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~" >> $TASK_ID/$REPORT_LOG

# resolve correct project
PROJECT=$(get_project ${ZIP_NAME})

echo " err_script: project - $PROJECT" >> $TASK_ID/$REPORT_LOG

if [ $SCRATCH == "true" ]
then
  ZIP_NAME=$ZIP_NAME\(s\)
fi

echo " err_script: component - $ZIP_NAME" >> $TASK_ID/$REPORT_LOG

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

echo " err_script: found - $FOUND" >> $TASK_ID/$REPORT_LOG

if [ $number_to_merge != 0 ]
then
  #find running item to be stopped
  RUNNING_ITEM=$(get_item_by_filter ${PROJECT} ${API_TOKEN} ${TASK_ID} ${TEST_PLAN_NAME} ${found_launch_id})
  echo $RUNNING_ITEM
  number_of_items=$(echo $RUNNING_ITEM | jq '.page.totalElements' --raw-output)
  echo " err_script: running_item - $RUNNING_ITEM" >> $TASK_ID/$REPORT_LOG

  if [ $number_of_items != 0 ]
  then
    item_id=$(echo $RUNNING_ITEM | jq '.content[0].id' --raw-output)
    item_uuid=$(get_item_uuid ${PROJECT} ${API_TOKEN} ${item_id} | jq '.[0].uuid' --raw-output)
    result=$(stop_error_item ${PROJECT} ${API_TOKEN} ${found_launch_uuid} ${item_uuid})
    echo $result
    echo " err_script: stopped - $result" >> $TASK_ID/$REPORT_LOG
    logs=$(logs_error_item ${PROJECT} ${API_TOKEN} ${found_launch_uuid} ${item_uuid} ${log1})
    echo $logs
    echo " logs_error_item - $logs" >> $TASK_ID/$REPORT_LOG
    logs=$(logs_error_item ${PROJECT} ${API_TOKEN} ${found_launch_uuid} ${item_uuid} ${log2})
    echo $logs
    echo " logs_error_item - $logs" >> $TASK_ID/$REPORT_LOG
    logs=$(logs_error_item ${PROJECT} ${API_TOKEN} ${found_launch_uuid} ${item_uuid} ${log3})
    echo $logs
    echo " logs_error_item - $logs" >> $TASK_ID/$REPORT_LOG
  fi
fi
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~" >> $TASK_ID/$REPORT_LOG