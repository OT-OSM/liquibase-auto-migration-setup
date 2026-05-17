pipeline {
    agent any

    environment {
        LIQUIBASE = "liquibase"
        PROPS = "liquibase.properties"
    }

    stages {

        stage('Validate') {
            steps {
                sh "${LIQUIBASE} validate --defaultsFile=${PROPS}"
            }
        }

        stage('Pre-Check DB') {
            steps {
                sh "psql -U admin -d appdb -c '\\dt'"
            }
        }

        stage('Deploy') {
            steps {
                sh "${LIQUIBASE} update --defaultsFile=${PROPS}"
            }
        }

        stage('Verify') {
            steps {
                sh "psql -U admin -d appdb -c '\\d users'"
            }
        }

        stage('History') {
            steps {
                sh "${LIQUIBASE} history --defaultsFile=${PROPS}"
            }
        }
    }

    post {
        success {
            echo "SUCCESS: Migration completed"
        }

        failure {
            echo "FAILED: Check logs"
            sh "${LIQUIBASE} status --defaultsFile=${PROPS}"
        }
    }
}
