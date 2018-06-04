email = "popu-servers+jenkins@populate.tools "
pipeline {
    agent any
    environment {
        PATH = "/home/ubuntu/.rbenv/shims:$PATH"
        GOBIERTO_ETL_UTILS = "/var/www/gobierto-etl-utils/current/"
        MATARO_ETL = "/var/www/gobierto-etl-mataro/current/"
        GOBIERTO = "/var/www/gobierto_staging/current/"
        WORKING_DIR="/tmp/mataro"
        MATARO_ID="8121"
    }
    stages {
        stage('Extract > Download data sources') {
            steps {
                sh "cd ${GOBIERTO_ETL_UTILS}; ruby operations/download/run.rb 'http://dadesobertes.mataro.cat/factura_2anys.csv' ${WORKING_DIR}/providers.csv"
            }
        }
        stage('Extract > Convert data to UTF8') {
            steps {
                sh "cd ${GOBIERTO_ETL_UTILS}; ruby operations/convert-to-utf8/run.rb ${WORKING_DIR}/providers.csv ${WORKING_DIR}/providers_utf8.csv"
            }
        }
        stage('Extract > Check CSV format') {
            steps {
                sh "cd ${GOBIERTO_ETL_UTILS}; ruby operations/check-csv/run.rb ${WORKING_DIR}/providers_utf8.csv"
            }
        }
        stage('Load > Clear previous providers') {
            steps {
              sh "cd ${GOBIERTO_ETL_UTILS}; ruby operations/gobierto_budgets/clear-previous-providers/run.rb ${MATARO_ID}"
            }
        }
        stage('Load > Import providers') {
            steps {
              sh "cd ${MATARO_ETL}; ruby operations/gobierto_budgets/import-providers/run.rb ${MATARO_ID} ${WORKING_DIR}/providers_utf8.csv"
            }
        }
        stage('Load > Publish activity') {
            steps {
              sh "echo ${MATARO_ID} > ${WORKING_DIR}/organization.id.txt"
              sh "cd ${GOBIERTO}; bin/rails runner ${GOBIERTO_ETL_UTILS}/operations/gobierto/publish-activity/run.rb providers_updated ${WORKING_DIR}/organization.id.txt"
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
