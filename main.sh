#!/bin/bash

#TODO
# pridat v importe do regularnych buildov tag non-scratch aby bolo mozne lahko filtrovat v historii
#treba ziskat info o scratch-buildoch a buidoch cez taskinfo -> brew taskinfo -v <task-id> + brew buildinfo <nvr> -> mas tu aj meno aj verziu, release, len to rozparsuj pekne
#poriesit userov a ich prihlasovanie cez curl
#poriesit jednotlive baliky aby boli ich vysledky importnute do spravnych projektov
#success rate opravit
#email server nastavit
#containery su nejake divne co sa tyka nvr a build_id

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

  if [[ " ${core_services_db[@]} " =~ " ${component} " ]]; then
    echo "core-services-db"
  elif [[ " ${python_maint[@]} " =~ " ${component} " ]]; then
    echo "python-maint"
  elif [[ " ${ruby[@]} " =~ " ${component} " ]]; then
    echo "ruby"
  else
    echo "default"
  fi
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

# get launch with appropiate task-id
function get_launch_by_task_id() {
  local project=$1
  local api_token=$2
  local task_id=$3

  echo $(curl -X GET "${RP_URL}/api/v1/${project}/launch?filter.has.attributeKey=task-id&filter.has.attributeValue=${task_id}" -H  "accept: */*" \
        -H "Authorization: Bearer $api_token")
}

# get launch with appropiate uuid
function get_launch_by_uuid() {
  local project=$1
  local api_token=$2
  local uuid=$3

  echo $(curl -X GET "${RP_URL}/api/v1/${project}/launch?filter.eq.uuid=${uuid}" -H  "accept: */*" \
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
FILE=$3
ZIP_NAME=$4
SCRATCH=$5
NVR=$6
TASK_ID=$7
TEST_PLAN_NAME=$8
ISSUER=$9

RP_URL="http://localhost:8080" #tuto zmena
TMP_FILE="reportportal-results.xml"
TASKINFO_FILE="taskinfo.txt"

# resolve correct project
PROJECT=$(get_project ${ZIP_NAME})

# get data about the task from brew
#brew taskinfo -v $TASK_ID > $TASKINFO_FILE
BUILD_ID="unknown" #$(grep "Build: " $TASKINFO_FILE | cut -d' ' -f3 | tr -d '()')

ZIP_FILE=$ZIP_NAME.zip

if [ $SCRATCH == "true" ]
then
  ZIP_FILE=$ZIP_NAME-scratch.zip
fi

if [ -z $BUILD_ID ]
then
  BUILD_ID="unknown"
fi

# create custom Xunit for ReportPortal
python3 standardize_xunit.py $FILE $TEST_PLAN_NAME $NVR $BUILD_ID $TASK_ID $SCRATCH $ISSUER > $TMP_FILE

zip -r $ZIP_FILE $TMP_FILE

# import data with appropriate tokens
UI_TOKEN=$(get_ui_token ${USERNAME} ${PASSWORD})

API_TOKEN=$(get_api_token ${UI_TOKEN})

#find launch with same task-id # tuto zmena
FOUND=$(get_launch_by_task_id merge ${API_TOKEN} ${TASK_ID})
#echo $FOUND
number_to_merge=$(echo $FOUND | jq '.page.totalElements' --raw-output)

#import new launch # tuto zmena
IMPORT=$(import_xunit merge ${API_TOKEN} ${ZIP_FILE} | jq '.message' --raw-output | cut -d' ' -f5)
#echo $IMPORT

#merge launches
if [ $number_to_merge != 0 ]
then
  # tuto zmena
  IMPORTED=$(get_launch_by_uuid merge ${API_TOKEN} ${IMPORT} | jq '.content' --raw-output)
  #echo $IMPORTED
  #merge_string='{"launches":[76,77,78],"mergeType":"BASIC","name":"merge","description":"","endTime":1609228254450,"startTime":1609228244313,"attributes":[{"key":"scratch-build","value":"false"}],"extendSuitesDescription":false}'
  FOUND=$(echo $FOUND | jq '.content' --raw-output)
  merge_string=$(python3 merge_launches.py "$FOUND" "$IMPORTED")
  # tuto zmena
  MERGED=$(merge_launches merge ${API_TOKEN} "${merge_string}")
  echo $MERGED
fi

rm $ZIP_FILE

