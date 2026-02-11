#!/bin/bash
source "/home/edu/.rvm/scripts/rvm"
set -e

WORKING_DIR=/tmp/mataro_plans
MATARO_INE_CODE=8121
API_HOST=http://madrid.gobierto.test:3000
PAM_PLAN_ID=63
URBAN_AGENDA_2030_PLAN_ID=64
API_TOKEN=LUhwRCoBENVvzLUJMcuYbXkg

# Clean working dir
rm -rf $WORKING_DIR
mkdir $WORKING_DIR

# [PAM] Extract > Download data sources - Plan data
cd $DEV_DIR/gobierto-etl-utils/; ruby operations/api-download/run.rb --source-url "https://apex.mataro.org/ords/rest/sigmav2/getjson/SIGMA/SEGUIMENT/id_plan/201872" --output-file $WORKING_DIR/PAM_source_data.json

# [PAM] Transform > Transform data
cd $DEV_DIR/gobierto-etl-mataro/; ruby operations/gobierto_plans/transform-projects/run.rb $WORKING_DIR/PAM_source_data.json $WORKING_DIR/PAM_request_body.json PAM

# [PAM] Load > Send create/update data to API
cd $DEV_DIR/gobierto-etl-mataro/; ruby operations/gobierto_plans/upsert-projects/run.rb $WORKING_DIR/PAM_request_body.json $API_HOST/api/v1/plans/$PAM_PLAN_ID

# [Urban Agenda 2030] Extract > Download data sources - Plan data
cd $DEV_DIR/gobierto-etl-utils/; ruby operations/api-download/run.rb --source-url "https://apex.mataro.org/ords/rest/sigmav2/getjson/SIGMA/SEGUIMENT/id_plan/253522" --output-file $WORKING_DIR/urban_agenda_2030_source_data.json

# [Urban Agenda 2030] Transform > Transform data
cd $DEV_DIR/gobierto-etl-mataro/; ruby operations/gobierto_plans/transform-projects/run.rb $WORKING_DIR/urban_agenda_2030_source_data.json $WORKING_DIR/urban_agenda_2030_request_body.json urban_agenda_2030

# [Urban Agenda 2030] Load > Send create/update data to API
cd $DEV_DIR/gobierto-etl-mataro/; ruby operations/gobierto_plans/upsert-projects/run.rb $WORKING_DIR/urban_agenda_2030_request_body.json $API_HOST/api/v1/plans/$URBAN_AGENDA_2030_PLAN_ID

# Load > Publish activity
echo $MATARO_INE_CODE > $WORKING_DIR/organization.id.txt
cd $DEV_DIR/gobierto/; bin/rails runner $DEV_DIR/gobierto-etl-utils/operations/gobierto/publish-activity/run.rb plans_projects_updated $WORKING_DIR/organization.id.txt
