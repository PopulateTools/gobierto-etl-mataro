#!/bin/bash
source "/Users/edu/.rvm/scripts/rvm"
set -e

WORKING_DIR=/tmp/mataro_investments
MATARO_INE_CODE=8121
API_HOST=http://mataro.gobierto.test
ATTACHMENTS_COLLECTION_ID=2026

# Clean working dir
rm -rf $WORKING_DIR
mkdir $WORKING_DIR

# Extract > Download data sources - Projects index
cd $DEV_DIR/gobierto-etl-utils/; ruby operations/download/run.rb "https://aplicacions.mataro.org:444/apex/rest/sigmav2/llistaobres2" $WORKING_DIR/llistaobres.json

# Extract > Download data sources - API resources
cd $DEV_DIR/gobierto-etl-utils/; ruby operations/download/run.rb "$API_HOST/gobierto_investments/api/v1/projects/meta" $WORKING_DIR/meta.json
cd $DEV_DIR/gobierto-etl-utils/; ruby operations/download/run.rb "$API_HOST/gobierto_investments/api/v1/projects/new" $WORKING_DIR/new.json

# Extract > Extract external ids of projects
cd $DEV_DIR/gobierto-etl-mataro/; ruby operations/gobierto_investments/extract-projects-external-ids-and-extra-data/run.rb $WORKING_DIR/llistaobres.json $WORKING_DIR/external_ids.txt $WORKING_DIR/projects_extra_data.json

# Extract > Download data sources - Individual projects
for i in $(cat $WORKING_DIR/external_ids.txt) ; do
  cd $DEV_DIR/gobierto-etl-utils/; ruby operations/download/run.rb "https://aplicacions.mataro.org:444/apex/rest/sigmav2/detallobre2/$i" $WORKING_DIR/downloaded_projects/$i.json
done

# Transform > Transform data
cd $DEV_DIR/gobierto-etl-mataro/; ruby operations/gobierto_investments/transform-projects/run.rb $WORKING_DIR/external_ids.txt $WORKING_DIR/meta.json $WORKING_DIR/projects_extra_data.json $WORKING_DIR/new.json $WORKING_DIR/downloaded_projects/ $WORKING_DIR/transformed_projects/ $API_HOST $ATTACHMENTS_COLLECTION_ID

# Load > Send create/update data and deletions to API
cd $DEV_DIR/gobierto-etl-mataro/; ruby operations/gobierto_investments/load-projects/run.rb $WORKING_DIR/external_ids.txt $WORKING_DIR/transformed_projects/ $API_HOST
cd $DEV_DIR/gobierto-etl-mataro/; ruby operations/gobierto_investments/delete-projects/run.rb $WORKING_DIR/external_ids.txt $API_HOST

# Load > Publish activity
echo $MATARO_INE_CODE > $WORKING_DIR/organization.id.txt
cd $DEV_DIR/gobierto/; bin/rails runner $DEV_DIR/gobierto-etl-utils/operations/gobierto/publish-activity/run.rb investments_projects_updated $WORKING_DIR/organization.id.txt
