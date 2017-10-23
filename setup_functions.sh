#!/bin/bash
#
# Copyright 2016 IBM Corp. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the “License”);
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#  https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an “AS IS” BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Color vars to be used in shell script output
RED='\033[0;31m'
YELLOW='\033[0;33m'
GREEN='\033[0;32m'
NC='\033[0m'

# load configuration variables
source .env

# capture the namespace where actions will be created
# as we need to pass it to our change listener
CURRENT_NAMESPACE=`bx wsk property get --namespace | awk '{print $3}'`
echo "Current namespace is $CURRENT_NAMESPACE."

function usage() {
  echo -e "${YELLOW}Usage: $0 [--install,--uninstall,--reinstall,--env]${NC}"
}

function install() {
  echo -e "${YELLOW}Installing..."

  echo "Creating overwatch package"
  bx wsk package create overwatch

  echo "Adding VCAP_SERVICES as parameter"
  bx wsk package update overwatch\
    --param cloudantUrl https://$CLOUDANT_USERNAME:$CLOUDANT_PASSWORD@$CLOUDANT_HOST\
    --param cloudantDbName $CLOUDANT_DB\
    --param watsonKey $VR_KEY\
    --param watsonClassifiers $VR_CLASSIFIERS\
    --param functionsHost $FUNCTIONS_APIHOST\
    --param functionsAuth $FUNCTIONS_AUTHORIZATION

  # we will need to listen to cloudant event
  echo "Binding cloudant"
   /whisk.system/cloudant
  bx wsk package bind /whisk.system/cloudant \
    overwatch-cloudant\
    --param username $CLOUDANT_USERNAME\
    --param password $CLOUDANT_PASSWORD\
    --param host $CLOUDANT_HOST

  echo "Creating trigger"
  bx wsk trigger create overwatch-cloudant-update-trigger --feed overwatch-cloudant/changes --param dbname $CLOUDANT_DB

  echo "Creating actions"
  bx wsk action create overwatch/analysis analysis.js

  # No Longer Needed
  #bx wsk action create overwatch/dataCleaner dataCleaner.js

  echo "Creating change listener action"
  #bx wsk action create overwatch-cloudant-changelistener changelistener.js --param targetNamespace $CURRENT_NAMESPACE

  #recently added to address removal of includeDoc support
  echo "Creating action sequence"
#bx wsk action create sequenceAction --sequence overwatch-cloudant/read,overwatch-cloudant
  bx wsk action create sequenceAction --sequence overwatch/analysis

  echo "Enabling change listener"
#bx wsk rule create overwatch-rule overwatch-cloudant-update-trigger overwatch-cloudant-changelistener
  bx wsk rule create overwatch-rule overwatch-cloudant-update-trigger overwatch/analysis

  echo "Set Cloudant Param on Trigger"
  bx wsk trigger update overwatch-cloudant-update-trigger --param dbname $CLOUDANT_DB

  echo -e "${GREEN}Install Complete${NC}"
  bx wsk list
}

function uninstall() {
  echo -e "${RED}Uninstalling..."

  echo "Removing actions..."
  bx wsk action delete overwatch/analysis
  #bx wsk action delete overwatch/dataCleaner

  echo "Removing rule..."
  bx wsk rule disable overwatch-rule
  bx wsk rule delete overwatch-rule

  #echo "Removing change listener..."
  #bx wsk action delete overwatch-cloudant-changelistener

  echo "Removing trigger..."
  bx wsk trigger delete overwatch-cloudant-update-trigger

  echo "Removing packages..."
  bx wsk package delete overwatch-cloudant
  bx wsk package delete overwatch

  echo -e "${GREEN}Uninstall Complete${NC}"
  bx wsk list
}

function showenv() {
  echo -e "${YELLOW}"
  echo CLOUDANT_USERNAME=$CLOUDANT_USERNAME
  echo CLOUDANT_PASSWORD=$CLOUDANT_PASSWORD
  echo CLOUDANT_HOST=$CLOUDANT_HOST
  echo CLOUDANT_DB=$CLOUDANT_DB
  echo VR_KEY=$VR_KEY
  echo -e "${NC}"
}

case "$1" in
"--install" )
install
;;
"--uninstall" )
uninstall
;;
"--update" )
update
;;
"--reinstall" )
uninstall
install
;;
"--env" )
showenv
;;
* )
usage
;;
esac
