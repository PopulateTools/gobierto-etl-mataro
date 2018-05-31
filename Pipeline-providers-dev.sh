#!/bin/bash

# Extract > Download data sources
cd /Users/fernando/proyectos/gobierto-etl-utils/; ruby operations/download/run.rb "http://dadesobertes.mataro.cat/factura_2anys.csv" /tmp/mataro/providers.csv

# Extract > Convert data to UTF8
cd /Users/fernando/proyectos/gobierto-etl-utils/; ruby operations/convert-to-utf8/run.rb /tmp/mataro/providers.csv /tmp/mataro/providers_utf8.csv

# Extract > Check CSV format
cd /Users/fernando/proyectos/gobierto-etl-utils/; ruby operations/check-csv/run.rb /tmp/mataro/providers_utf8.csv

# Load > Clear previous providers
cd /Users/fernando/proyectos/gobierto-etl-utils/; ruby operations/gobierto_budgets/clear-previous-providers/run.rb 8121

# Load > Import providers
cd /Users/fernando/proyectos/gobierto-etl-mataro/; ruby operations/gobierto_budgets/import-providers/run.rb 8121 /tmp/mataro/providers_utf8.csv

# Load > Publish activity
echo "8121" > /tmp/mataro/organization.id.txt
cd /Users/fernando/proyectos/gobierto/; bin/rails runner /Users/fernando/proyectos/gobierto-etl-utils/operations/gobierto/publish-activity/run.rb providers_updated /tmp/mataro/organization.id.txt

