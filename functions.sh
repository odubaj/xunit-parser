#!/bin/bash

#core-services-db team components
core_services_db=("classloader-leak-test-framework gd gdbm libnsl2 nss_nis rdate yp-tools ypbind ypserv
                  dejagnu gc less libatomic_ops libconfig libdb mutt galera Judy mariadb mariadb-connector-c 
                  mariadb-connector-odbc mecab mecab-ipadic multilib-rpm-config mysql python-PyMySQL 
                  java-comment-preprocessor jna mariadb-java-client postgresql-jdbc properties-maven-plugin 
                  postgresql-jdbc properties-maven-plugin replacer transfig unixODBC argparse-manpage 
                  autoconf autoconf213 automake CUnit libpq libstemmer libtool ongres-scram postgresql 
                  postgresql-odbc pgaudit postgres-decoderbufs python-markdown python-psycopg2 python-pymongo 
                  scons tokyocabinet cpio libarchive libzip ncompress sqlite star tar xdelta xz zlib 
                  cronie at crontabs libEMF lockdev pstoedit psutils recode")

#python-maint team components
python_maint=("babel Cython libyaml pyparsing pytest python-attrs python-backports python-backports-ssl_match_hostname 
              python-chardet python-click python-configobj python-coverage python-cryptography-vectors python-dateutil 
              python-decorator python-distutils-extra python-dns python-docutils python-ethtool python-funcsigs 
              python-html5lib python-hypothesis python-imagesize python-iniparse python-iso8601 python-jinja2 python-lxml 
              python-mako python-markupsafe python-mock python-nose python-packaging python-pillow python-pip python-pluggy 
              python-pretend python-py python-pygments python-pysocks python-pytest-mock python-requests python-rpm-generators 
              python-rpm-macros python-scour python-setuptools python-setuptools_scm python-six python-slip python-snowballstemmer 
              python-sphinx python-sphinx_rtd_theme python-sphinx-theme-alabaster python-sphinxcontrib-websupport python-sqlalchemy 
              python-sure python-systemd python-unittest2 python-urllib3 python-virtualenv python-webencodings python-wheel 
              python-whoosh python2 python2-pip python2-rpm-macros python2-setuptools python3 python36 python38 pytz PyYAML")

#ruby team components
ruby=("aspell aspell-en compat-libtiff3 dblatex execstack exempi gdisk giflib groff hunspell-ar jbig2dec jbigkit 
      libcgroup libjpeg-turbo libmng libpipeline libpng libpng12 libpng15 libtiff mailx s-nail man-db man-pages 
      man-pages-overrides numpy openblas openblas-srpm-macros openjpeg2 qhull scipy git mercurial ruby rubygem-abrt 
      rubygem-bson rubygem-bundler rubygem-coderay rubygem-diff-lcs rubygem-kramdown rubygem-mongo rubygem-mysql2 
      rubygem-pg rubygem-rspec rubygem-rspec-core rubygem-rspec-expectations rubygem-rspec-its rubygem-rspec-mocks 
      rubygem-rspec-support rubygem-thread_order python-distro libuv nodejs nodejs-nodemon nodejs-packaging 
      uglify-js web-assets")

# get project by component name
function get_project() {
  local component=$1
  echo "default"

#   if [[ " ${core_services_db[@]} " =~ " ${component} " ]]; then
#     echo "core-services-db"
#   elif [[ " ${python_maint[@]} " =~ " ${component} " ]]; then
#     echo "python-maint"
#   elif [[ " ${ruby[@]} " =~ " ${component} " ]]; then
#     echo "ruby"
#   else
#     echo "default"
#   fi
}

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

# get launch with appropiate uuid
function get_launch_by_uuid() {
  local project=$1
  local api_token=$2
  local uuid=$3

  echo $(curl -X GET "${RP_URL}/api/v1/${project}/launch?filter.eq.uuid=${uuid}" -H  "accept: */*" \
        -H "Authorization: Bearer $api_token")
}

# get launch with appropiate task-id
function get_launch_by_task_id() {
  local project=$1
  local api_token=$2
  local task_id=$3

  echo $(curl -X GET "${RP_URL}/api/v1/${project}/launch?filter.has.attributeKey=task-id&filter.has.attributeValue=${task_id}" -H  "accept: */*" \
        -H "Authorization: Bearer $api_token")
}

# merge two launches
function merge_launches() {
  local project=$1
  local api_token=$2
  local data=$3

  echo $(curl -X POST "${RP_URL}/api/v1/${project}/launch/merge" -H  "accept: */*" -H  "Content-Type: application/json" \
        -H "Authorization: Bearer $api_token" \
        -d "$data")
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

# find item
function get_item_by_filter() {
  local project=$1
  local api_token=$2
  local task_id=$3
  local name=$4
  local launch_id=$5

  echo $(curl -X GET "${RP_URL}/api/v1/${project}/item?filter.has.attributeKey=task-id&filter.has.attributeValue=${task_id}&filter.eq.launchId=${launch_id}&filter.eq.name=${name}&filter.eq.status=IN_PROGRESS&isLatest=false&launchesLimit=0" \
        -H "accept: */*" \
        -H "Authorization: Bearer $api_token")
}

# find item uuid
function get_item_uuid() {
  local project=$1
  local api_token=$2
  local item_id=$3

  echo $(curl -X GET "${RP_URL}/api/v1/${project}/item/items?ids=${item_id}" \
        -H  "accept: */*" \
        -H "Authorization: Bearer $api_token")
}

# stop and delete running item
function stop_delete_item() {
  local project=$1
  local api_token=$2
  local launch_uuid=$3
  local item_id=$4
  local item_uuid=$5
  local time=$(echo $(($(date +%s%N)/1000000)))

  echo $(curl -X PUT "${RP_URL}/api/v1/${project}/item/${item_uuid}" \
        -H  "accept: */*" -H  "Content-Type: application/json" \
        -H "Authorization: Bearer $api_token" \
        -d '{"endTime":"'$time'","launchUuid":"'$launch_uuid'", "status": "PASSED"}')

  echo $(curl -X DELETE "${RP_URL}/api/v1/${project}/item/${item_id}" \
        -H  "accept: */*" \
        -H "Authorization: Bearer $api_token")
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

#creating new launch
function create_new_launch() {
  local project=$1
  local api_token=$2
  local name=$3
  local scratch=$4
  local nvr=$5
  local task_id=$6
  local issuer=$7
  local component=$8
  local suite_name=$9
  local time=$(echo $(($(date +%s%N)/1000000)))
  if [[ $suite_name == *"redhat-module"* ]]; then
    nvr_name="nsvc"
    add_module=',{"key":"module","value":"redhat-module"}'
  else
    nvr_name="nvr"
    add_module=""
  fi

  echo $(curl -X POST "${RP_URL}/api/v1/${project}/launch" -H  "accept: */*" -H  "Content-Type: application/json" \
        -H "Authorization: Bearer $api_token" \
        -d '{"name":"'$name'","description":"","startTime":"'$time'","mode":"DEFAULT","attributes":[{"key":"task-id","value":"'$task_id'"},{"key":"scratch-build","value":"'$scratch'"},{"key":"component","value":"'$component'"},{"key":"'$nvr_name'","value":"'$nvr'"},{"key":"issuer","value":"'$issuer'"}'$add_module']}')
}

#stopping created launch
function stop_launch() {
  local project=$1
  local api_token=$2
  local uuid=$3
  local time=$(echo $(($(date +%s%N)/1000000)))

  echo $(curl -X PUT "${RP_URL}/api/v1/${project}/launch/${uuid}/finish" \
        -H  "accept: */*" -H  "Content-Type: application/json" \
        -H "Authorization: Bearer $api_token" \
        -d '{"endTime":"'$time'","status": "PASSED"}')
}

#creating test-suite
function create_test_suite() {
  local project=$1
  local api_token=$2
  local launch_uuid=$3
  local name=$4
  local scratch=$5
  local nvr=$6
  local task_id=$7
  local issuer=$8
  local time=$(echo $(($(date +%s%N)/1000000)))
  if [[ $name == *"redhat-module"* ]]; then
    nvr_name="nsvc"
    add_module=',{"key":"module","value":"redhat-module"}'
  else
    nvr_name="nvr"
    add_module=""
  fi

  echo $(curl -X POST "${RP_URL}/api/v1/${project}/item" -H  "accept: */*" -H  "Content-Type: application/json" \
        -H "Authorization: Bearer $api_token" \
        -d '{"name":"'$name'","startTime":"'$time'","type":"suite","launchUuid":"'$launch_uuid'","description":"","attributes":[{"key":"task-id","value":"'$task_id'"},{"key":"scratch-build","value":"'$scratch'"},{"key":"'$nvr_name'","value":"'$nvr'"},{"key":"issuer","value":"'$issuer'"}'$add_module']}')
}

# stop running item with error
function stop_error_item() {
  local project=$1
  local api_token=$2
  local launch_uuid=$3
  local item_uuid=$4
  local time=$(echo $(($(date +%s%N)/1000000)))

  echo $(curl -X PUT "${RP_URL}/api/v1/${project}/item/${item_uuid}" \
        -H  "accept: */*" -H  "Content-Type: application/json" \
        -H "Authorization: Bearer $api_token" \
        -d '{"endTime":"'$time'","launchUuid":"'$launch_uuid'", "status": "FAILED","description":"Infrastructure Error during testing","issue":{"autoAnalyzed": false,"ignoreAnalyzer": true,"issueType":"si001"}}')
}

# import logs before ending with error
function logs_error_item() {
  local project=$1
  local api_token=$2
  local launch_uuid=$3
  local item_uuid=$4
  local log=$5
  local time=$(echo $(($(date +%s%N)/1000000)))

  echo $(curl -X POST "${RP_URL}/api/v1/${project}/log" -H  "accept: */*" -H  "Content-Type: application/json" \
        -H "Authorization: Bearer $api_token" \
        -d '{"time":"'$time'","launchUuid":"'$launch_uuid'","itemUuid":"'$item_uuid'","level": 40000,"message": "'$log'"}')
}

#RP_URL="http://localhost:8080"
RP_URL="http://reportportal.osci.redhat.com"
