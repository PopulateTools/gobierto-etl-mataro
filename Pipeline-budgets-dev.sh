#!/bin/bash

# Extract > Download data sources
cd $DEV_DIR/gobierto-etl-utils/; ruby operations/download/run.rb "http://dadesobertes.mataro.cat/pressupost_2017.csv" /tmp/mataro/pressupost_2017.csv
cd $DEV_DIR/gobierto-etl-utils/; ruby operations/download/run.rb "http://dadesobertes.mataro.cat/pressupost_2018.csv" /tmp/mataro/pressupost_2018.csv

# Extract > Convert data to UTF8
cd $DEV_DIR/gobierto-etl-utils/; ruby operations/convert-to-utf8/run.rb /tmp/mataro/pressupost_2017.csv /tmp/mataro/pressupost_2017_utf8.csv
cd $DEV_DIR/gobierto-etl-utils/; ruby operations/convert-to-utf8/run.rb /tmp/mataro/pressupost_2018.csv /tmp/mataro/pressupost_2018_utf8.csv

# Extract > Clean wrong quotes
cd $DEV_DIR/gobierto-etl-mataro/; ruby operations/gobierto_budgets/clean-quotes/run.rb /tmp/mataro/pressupost_2017_utf8.csv /tmp/mataro/pressupost_2017_utf8_clean.csv
cd $DEV_DIR/gobierto-etl-mataro/; ruby operations/gobierto_budgets/clean-quotes/run.rb /tmp/mataro/pressupost_2018_utf8.csv /tmp/mataro/pressupost_2018_utf8_clean.csv

# Extract > Check CSV format
cd $DEV_DIR/gobierto-etl-utils/; ruby operations/check-csv/run.rb /tmp/mataro/pressupost_2017_utf8_clean.csv
cd $DEV_DIR/gobierto-etl-utils/; ruby operations/check-csv/run.rb /tmp/mataro/pressupost_2018_utf8_clean.csv

# Transform > Transform planned budgets data files
cd $DEV_DIR/gobierto-etl-mataro/; ruby operations/gobierto_budgets/transform-planned/run.rb /tmp/mataro/pressupost_2017_utf8_clean.csv /tmp/mataro/budgets-planned-2017-transformed.json 2017
cd $DEV_DIR/gobierto-etl-mataro/; ruby operations/gobierto_budgets/transform-planned/run.rb /tmp/mataro/pressupost_2018_utf8_clean.csv /tmp/mataro/budgets-planned-2018-transformed.json 2018

# Transform > Transform executed budgets data files
cd $DEV_DIR/gobierto-etl-mataro/; ruby operations/gobierto_budgets/transform-executed/run.rb /tmp/mataro/pressupost_2017_utf8_clean.csv /tmp/mataro/budgets-executed-2017-transformed.json 2017
cd $DEV_DIR/gobierto-etl-mataro/; ruby operations/gobierto_budgets/transform-executed/run.rb /tmp/mataro/pressupost_2018_utf8_clean.csv /tmp/mataro/budgets-executed-2018-transformed.json 2018

# Transform > Transform planned updated data files
cd $DEV_DIR/gobierto-etl-mataro/; ruby operations/gobierto_budgets/transform-planned-updated/run.rb /tmp/mataro/pressupost_2017_utf8_clean.csv /tmp/mataro/budgets-planned-updated-2017-transformed.json 2017
cd $DEV_DIR/gobierto-etl-mataro/; ruby operations/gobierto_budgets/transform-planned-updated/run.rb /tmp/mataro/pressupost_2018_utf8_clean.csv /tmp/mataro/budgets-planned-updated-2018-transformed.json 2018

# Load > Import planned budgets
cd $DEV_DIR/gobierto-etl-utils/; ruby operations/gobierto_budgets/import-planned-budgets/run.rb /tmp/mataro/budgets-planned-2017-transformed.json 2017
cd $DEV_DIR/gobierto-etl-utils/; ruby operations/gobierto_budgets/import-planned-budgets/run.rb /tmp/mataro/budgets-planned-2018-transformed.json 2018

# Load > Import executed budgets
cd $DEV_DIR/gobierto-etl-utils/; ruby operations/gobierto_budgets/import-executed-budgets/run.rb /tmp/mataro/budgets-executed-2017-transformed.json 2017
cd $DEV_DIR/gobierto-etl-utils/; ruby operations/gobierto_budgets/import-executed-budgets/run.rb /tmp/mataro/budgets-executed-2018-transformed.json 2018

# Load > Import planned updated budgets
cd $DEV_DIR/gobierto-etl-utils/; ruby operations/gobierto_budgets/import-planned-budgets-updated/run.rb /tmp/mataro/budgets-planned-updated-2017-transformed.json 2017
cd $DEV_DIR/gobierto-etl-utils/; ruby operations/gobierto_budgets/import-planned-budgets-updated/run.rb /tmp/mataro/budgets-planned-updated-2018-transformed.json 2018

# Load > Calculate totals
echo "8121" > /tmp/mataro/organization.id.txt
cd $DEV_DIR/gobierto-etl-utils/; ruby operations/gobierto_budgets/update_total_budget/run.rb "2017 2018" /tmp/mataro/organization.id.txt

# Load > Calculate bubbles
cd $DEV_DIR/gobierto-etl-utils/; ruby operations/gobierto_budgets/bubbles/run.rb /tmp/mataro/organization.id.txt

# Load > Calculate annual data
cd $DEV_DIR/gobierto/; bin/rails runner $DEV_DIR/gobierto-etl-utils/operations/gobierto_budgets/annual_data/run.rb "2017 2018" /tmp/mataro/organization.id.txt

# Load > Publish activity
cd $DEV_DIR/gobierto/; bin/rails runner $DEV_DIR/gobierto-etl-utils/operations/gobierto/publish-activity/run.rb budgets_updated /tmp/mataro/organization.id.txt
