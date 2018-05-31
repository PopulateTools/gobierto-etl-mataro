email = "popu-servers+jenkins@populate.tools "
pipeline {
    agent any
    environment {
        PATH = "/home/ubuntu/.rbenv/shims:$PATH"
        GOBIERTO_ETL_UTILS = "/var/www/gobierto-etl-utils/current/"
        MATARO_ETL = "/var/www/gobierto-etl-mataro/current/"
        GOBIERTO = "/var/www/gobierto_staging/current/"
    }
    stages {
        stage('Extract > Download data sources') {
            steps {
                sh "cd ${GOBIERTO_ETL_UTILS}; ruby operations/download/run.rb 'http://dadesobertes.mataro.cat/pressupost_2017.csv' /tmp/mataro/pressupost_2017.csv"
                sh "cd ${GOBIERTO_ETL_UTILS}; ruby operations/download/run.rb 'http://dadesobertes.mataro.cat/pressupost_2018.csv' /tmp/mataro/pressupost_2018.csv"
            }
        }
        stage('Extract > Convert data to UTF8') {
            steps {
                sh "cd ${GOBIERTO_ETL_UTILS}; ruby operations/convert-to-utf8/run.rb /tmp/mataro/pressupost_2017.csv /tmp/mataro/pressupost_2017_utf8.csv"
                sh "cd ${GOBIERTO_ETL_UTILS}; ruby operations/convert-to-utf8/run.rb /tmp/mataro/pressupost_2018.csv /tmp/mataro/pressupost_2018_utf8.csv"
            }
        }
        stage('Extract > Clean wrong quotes') {
            steps {
                sh "cd ${MATARO_ETL}; ruby operations/gobierto_budgets/clean-quotes/run.rb /tmp/mataro/pressupost_2017_utf8.csv /tmp/mataro/pressupost_2017_utf8_clean.csv"
                sh "cd ${MATARO_ETL}; ruby operations/gobierto_budgets/clean-quotes/run.rb /tmp/mataro/pressupost_2018_utf8.csv /tmp/mataro/pressupost_2018_utf8_clean.csv"
            }
        }
        stage('Extract > Check CSV format') {
            steps {
                sh "cd ${GOBIERTO_ETL_UTILS}; ruby operations/check-csv/run.rb /tmp/mataro/pressupost_2017_utf8_clean.csv"
                sh "cd ${GOBIERTO_ETL_UTILS}; ruby operations/check-csv/run.rb /tmp/mataro/pressupost_2018_utf8_clean.csv"
            }
        }
        stage('Transform > Transform planned budgets data files') {
            steps {
                sh "cd ${MATARO_ETL}; ruby operations/gobierto_budgets/transform-planned/run.rb /tmp/mataro/pressupost_2017_utf8_clean.csv /tmp/mataro/budgets-planned-2017-transformed.json 2017"
                sh "cd ${MATARO_ETL}; ruby operations/gobierto_budgets/transform-planned/run.rb /tmp/mataro/pressupost_2018_utf8_clean.csv /tmp/mataro/budgets-planned-2018-transformed.json 2018"
            }
        }
        stage('Transform > Transform executed budgets data files') {
            steps {
                sh "cd ${MATARO_ETL}; ruby operations/gobierto_budgets/transform-executed/run.rb /tmp/mataro/pressupost_2017_utf8_clean.csv /tmp/mataro/budgets-executed-2017-transformed.json 2017"
                sh "cd ${MATARO_ETL}; ruby operations/gobierto_budgets/transform-executed/run.rb /tmp/mataro/pressupost_2018_utf8_clean.csv /tmp/mataro/budgets-executed-2018-transformed.json 2018"
            }
        }
        stage('Transform > Transform planned updated budgets data files') {
            steps {
                sh "cd ${MATARO_ETL}; ruby operations/gobierto_budgets/transform-planned-updated/run.rb /tmp/mataro/pressupost_2017_utf8_clean.csv /tmp/mataro/budgets-planned-updated-2017-transformed.json 2017"
                sh "cd ${MATARO_ETL}; ruby operations/gobierto_budgets/transform-planned-updated/run.rb /tmp/mataro/pressupost_2018_utf8_clean.csv /tmp/mataro/budgets-planned-updated-2018-transformed.json 2018"
            }
        }
        stage('Load > Import planned budgets') {
            steps {
                sh "cd ${MATARO_ETL}; ruby operations/gobierto_budgets/import-planned-budgets/run.rb /tmp/mataro/budgets-planned-2017-transformed.json 2017"
                sh "cd ${MATARO_ETL}; ruby operations/gobierto_budgets/import-planned-budgets/run.rb /tmp/mataro/budgets-planned-2018-transformed.json 2018"
            }
        }
        stage('Load > Import executed budgets') {
            steps {
                sh "cd ${MATARO_ETL}; ruby operations/gobierto_budgets/import-executed-budgets/run.rb /tmp/mataro/budgets-executed-2017-transformed.json 2017"
                sh "cd ${MATARO_ETL}; ruby operations/gobierto_budgets/import-executed-budgets/run.rb /tmp/mataro/budgets-executed-2018-transformed.json 2018"
            }
        }
        stage('Load > Import planned updated budgets') {
            steps {
                sh "cd ${MATARO_ETL}; ruby operations/gobierto_budgets/import-planned-budgets-updated/run.rb /tmp/mataro/budgets-planned-updated-2017-transformed.json 2017"
                sh "cd ${MATARO_ETL}; ruby operations/gobierto_budgets/import-planned-budgets-updated/run.rb /tmp/mataro/budgets-planned-updated-2018-transformed.json 2018"
            }
        }
        stage('Load > Calculate totals') {
            steps {
              sh "echo '8121' > /tmp/mataro/organization.id.txt"
              sh "cd ${GOBIERTO_ETL_UTILS}; ruby operations/gobierto_budgets/update_total_budget/run.rb '2017 2018' /tmp/mataro/organization.id.txt"
            }
        }
        stage('Load > Calculate bubbles') {
            steps {
              sh "cd ${GOBIERTO_ETL_UTILS}; ruby operations/gobierto_budgets/bubbles/run.rb /tmp/mataro/organization.id.txt"
            }
        }
        stage('Load > Calculate annual data') {
            steps {
              sh "cd ${GOBIERTO}; bin/rails runner /var/www/gobierto-etl-utils/current/operations/gobierto_budgets/annual_data/run.rb '2017 2018' /tmp/mataro/organization.id.txt"
            }
        }
        stage('Load > Publish activity') {
            steps {
              sh "cd ${GOBIERTO}; bin/rails runner /var/www/gobierto-etl-utils/current/operations/gobierto/publish-activity/run.rb budgets_updated /tmp/mataro/organization.id.txt"
            }
        }
    }
    post {
        failure {
            echo 'This will run only if failed'
            mail body: "Project: ${env.JOB_NAME} - Build Number: ${env.BUILD_NUMBER} - URL de build: ${env.BUILD_URL}",
                charset: 'UTF-8',
                subject: "ERROR CI: Project name -> ${env.JOB_NAME}",
                to: email

        }
    }
}
