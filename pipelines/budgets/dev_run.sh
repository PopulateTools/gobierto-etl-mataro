#!/bin/bash

# Requieres one argument witht he domain of the site, i.e madrid.gobierto.test

set -e

WORKING_DIR=/tmp/mataro
MATARO_INE_CODE=8121

# Clean working dir
rm -rf $WORKING_DIR
mkdir $WORKING_DIR

echo $MATARO_INE_CODE > $WORKING_DIR/mataro_id.txt

# Extract > Download data sources
cd $DEV_DIR/gobierto-etl-utils/; ruby operations/download/run.rb "https://dadesobertes.mataro.cat/pressupost_2023.csv" $WORKING_DIR/pressupost_2023.csv
cd $DEV_DIR/gobierto-etl-utils/; ruby operations/download/run.rb "https://dadesobertes.mataro.cat/pressupost_2024.csv" $WORKING_DIR/pressupost_2024.csv

# Extract > Convert data to UTF8
cd $DEV_DIR/gobierto-etl-utils/; ruby operations/convert-to-utf8/run.rb $WORKING_DIR/pressupost_2023.csv $WORKING_DIR/pressupost_2023_utf8.csv ISO-8859-1
cd $DEV_DIR/gobierto-etl-utils/; ruby operations/convert-to-utf8/run.rb $WORKING_DIR/pressupost_2024.csv $WORKING_DIR/pressupost_2024_utf8.csv ISO-8859-1

# Extract > Clean wrong quotes
cd $DEV_DIR/gobierto-etl-mataro/; ruby operations/gobierto_budgets/clean-quotes/run.rb $WORKING_DIR/pressupost_2023_utf8.csv $WORKING_DIR/pressupost_2023_utf8_clean.csv
cd $DEV_DIR/gobierto-etl-mataro/; ruby operations/gobierto_budgets/clean-quotes/run.rb $WORKING_DIR/pressupost_2024_utf8.csv $WORKING_DIR/pressupost_2024_utf8_clean.csv

# Extract > Check CSV format
cd $DEV_DIR/gobierto-etl-utils/; ruby operations/check-csv/run.rb $WORKING_DIR/pressupost_2023_utf8_clean.csv
cd $DEV_DIR/gobierto-etl-utils/; ruby operations/check-csv/run.rb $WORKING_DIR/pressupost_2024_utf8_clean.csv

# Transform > Transform planned budgets data files
cd $DEV_DIR/gobierto-etl-mataro/; ruby operations/gobierto_budgets/transform-planned/run.rb $WORKING_DIR/pressupost_2023_utf8_clean.csv $WORKING_DIR/budgets-planned-2023-transformed.json 2023
cd $DEV_DIR/gobierto-etl-mataro/; ruby operations/gobierto_budgets/transform-planned/run.rb $WORKING_DIR/pressupost_2024_utf8_clean.csv $WORKING_DIR/budgets-planned-2024-transformed.json 2024

# Transform > Transform executed budgets data files
cd $DEV_DIR/gobierto-etl-mataro/; ruby operations/gobierto_budgets/transform-executed/run.rb $WORKING_DIR/pressupost_2023_utf8_clean.csv $WORKING_DIR/budgets-executed-2023-transformed.json 2023
cd $DEV_DIR/gobierto-etl-mataro/; ruby operations/gobierto_budgets/transform-executed/run.rb $WORKING_DIR/pressupost_2024_utf8_clean.csv $WORKING_DIR/budgets-executed-2024-transformed.json 2024

# Transform > Transform planned updated data files
cd $DEV_DIR/gobierto-etl-mataro/; ruby operations/gobierto_budgets/transform-planned-updated/run.rb $WORKING_DIR/pressupost_2023_utf8_clean.csv $WORKING_DIR/budgets-planned-updated-2023-transformed.json 2023
cd $DEV_DIR/gobierto-etl-mataro/; ruby operations/gobierto_budgets/transform-planned-updated/run.rb $WORKING_DIR/pressupost_2024_utf8_clean.csv $WORKING_DIR/budgets-planned-updated-2024-transformed.json 2024

# Load > Clear existing budgets
cd $DEV_DIR/gobierto-etl-utils/; ruby operations/gobierto_budgets/clear-budgets/run.rb $WORKING_DIR/mataro_id.txt 2023
cd $DEV_DIR/gobierto-etl-utils/; ruby operations/gobierto_budgets/clear-budgets/run.rb $WORKING_DIR/mataro_id.txt 2024

# Load > Import planned budgets
cd $DEV_DIR/gobierto-etl-utils/; ruby operations/gobierto_budgets/import-planned-budgets/run.rb $WORKING_DIR/budgets-planned-2023-transformed.json 2023
cd $DEV_DIR/gobierto-etl-utils/; ruby operations/gobierto_budgets/import-planned-budgets/run.rb $WORKING_DIR/budgets-planned-2024-transformed.json 2024

# Load > Import executed budgets
cd $DEV_DIR/gobierto-etl-utils/; ruby operations/gobierto_budgets/import-executed-budgets/run.rb $WORKING_DIR/budgets-executed-2023-transformed.json 2023
cd $DEV_DIR/gobierto-etl-utils/; ruby operations/gobierto_budgets/import-executed-budgets/run.rb $WORKING_DIR/budgets-executed-2024-transformed.json 2024

# Load > Import planned updated budgets
cd $DEV_DIR/gobierto-etl-utils/; ruby operations/gobierto_budgets/import-planned-budgets-updated/run.rb $WORKING_DIR/budgets-planned-updated-2023-transformed.json 2023
cd $DEV_DIR/gobierto-etl-utils/; ruby operations/gobierto_budgets/import-planned-budgets-updated/run.rb $WORKING_DIR/budgets-planned-updated-2024-transformed.json 2024

# Load > Import custom categories
cd $DEV_DIR/gobierto; bin/rails runner $DEV_DIR/gobierto-etl-mataro/operations/gobierto_budgets/extract-custom-categories/run.rb $WORKING_DIR/pressupost_2023_utf8_clean.csv $1
cd $DEV_DIR/gobierto; bin/rails runner $DEV_DIR/gobierto-etl-mataro/operations/gobierto_budgets/extract-custom-categories/run.rb $WORKING_DIR/pressupost_2024_utf8_clean.csv $1

# Load > Calculate totals
echo $MATARO_INE_CODE > $WORKING_DIR/organization.id.txt
cd $DEV_DIR/gobierto-etl-utils/; ruby operations/gobierto_budgets/update_total_budget/run.rb "2023 2024" $WORKING_DIR/organization.id.txt

# Load > Calculate bubbles
cd $DEV_DIR/gobierto-etl-utils/; ruby operations/gobierto_budgets/bubbles/run.rb $WORKING_DIR/organization.id.txt

# Load > Calculate annual data
cd $DEV_DIR/gobierto/; bin/rails runner $DEV_DIR/gobierto-etl-utils/operations/gobierto_budgets/annual_data/run.rb "2023 2024" $WORKING_DIR/organization.id.txt

# Load > Publish activity
cd $DEV_DIR/gobierto/; bin/rails runner $DEV_DIR/gobierto-etl-utils/operations/gobierto/publish-activity/run.rb budgets_updated $WORKING_DIR/organization.id.txt

# Clear cache
cd $DEV_DIR/gobierto/; bin/rails runner $DEV_DIR/gobierto-etl-utils/operations/gobierto/clear-cache/run.rb --site-organization-id "$MATARO_INE_CODE" --namespace "GobiertoBudgets"
