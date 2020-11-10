#!/bin/bash

function get_ui_token() {
  local username=$1
  local password=$2

  echo $(curl --header "Content-Type: application/x-www-form-urlencoded" \
              --request POST \
              --data "grant_type=password&username=$username&password=$password" \
              --user "ui:uiman" \
              http://reportportal.infrastructure.testing-farm.io/uat/sso/oauth/token | \
              jq '.access_token' --raw-output)

}

function get_api_token() {
  local ui_token=$1

  local api_token="$(curl --header "Authorization: Bearer $ui_token" \
                          --request GET \
                          http://reportportal.infrastructure.testing-farm.io/uat/sso/me/apitoken | \
                          jq ".access_token" --raw-output)"

  if [[ "$api_token"="null" ]]
  then
    echo $(curl --header "Authorization: Bearer $ui_token" \
                --request POST \
                http://reportportal.infrastructure.testing-farm.io/uat/sso/me/apitoken | \
                jq ".access_token" --raw-output)
  else
    echo ${api_token}
  fi
}

