#!/bin/bash

WORKING_DIR=$WORKING_DIR
MATARO_INE_CODE=8121

# Clean working dir
rm -rf $WORKING_DIR
mkdir $WORKING_DIR

# Extract > Download data sources
cd $DEV_DIR/gobierto-etl-utils/; ruby operations/download/run.rb "http://dadesobertes.mataro.cat/factura_2anys.csv" $WORKING_DIR/providers.csv

# Extract > Convert data to UTF8
cd $DEV_DIR/gobierto-etl-utils/; ruby operations/convert-to-utf8/run.rb $WORKING_DIR/providers.csv $WORKING_DIR/providers_utf8.csv

# Extract > Check CSV format
cd $DEV_DIR/gobierto-etl-utils/; ruby operations/check-csv/run.rb $WORKING_DIR/providers_utf8.csv

# Load > Clear previous providers
cd $DEV_DIR/gobierto-etl-utils/; ruby operations/gobierto_budgets/clear-previous-providers/run.rb $MATARO_INE_CODE

# Load > Import providers
cd $DEV_DIR/gobierto-etl-mataro/; ruby operations/gobierto_budgets/import-providers/run.rb $MATARO_INE_CODE $WORKING_DIR/providers_utf8.csv

# Load > Publish activity
echo "8121" > $WORKING_DIR/organization.id.txt
cd $DEV_DIR/gobierto/; bin/rails runner $DEV_DIR/gobierto-etl-utils/operations/gobierto/publish-activity/run.rb providers_updated $WORKING_DIR/organization.id.txt

