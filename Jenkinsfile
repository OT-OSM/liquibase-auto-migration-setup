pipeline {
    agent any

    environment {
        LIQUIBASE = "liquibase"
        PROPS = "liquibase.properties"

        DB_URL = "jdbc:postgresql://localhost:5432/appdb"
        DB_USER = "admin"
        DB_PASS = "admin"
    }

    stages {

        stage('Checkout Code') {
            steps {
                checkout scm
            }
        }

        stage('Pre-Validation') {
            steps {
                sh "echo 'Checking workspace...'"
                sh "ls -R"
            }
        }

        stage('Database Connectivity Check') {
            steps {
                sh "psql -U ${DB_USER} -d appdb -c '\\dt'"
            }
        }

        stage('Liquibase Validate') {
            steps {
                sh "${LIQUIBASE} validate --defaultsFile=${PROPS}"
            }
        }

        stage('Check Database Lock') {
            steps {
                sh "${LIQUIBASE} list-locks --defaultsFile=${PROPS} || true"
            }
        }

        stage('Update Schema (Incremental Migration)') {
            steps {
                sh "${LIQUIBASE} update --defaultsFile=${PROPS}"
            }
        }

        stage('Verify Schema Changes') {
            steps {
                sh "psql -U ${DB_USER} -d appdb -c '\\d users'"
                sh "psql -U ${DB_USER} -d appdb -c 'SELECT * FROM users;'"
            }
        }

        stage('Audit History Check') {
            steps {
                sh "${LIQUIBASE} history --defaultsFile=${PROPS}"
                sh "psql -U ${DB_USER} -d appdb -c 'SELECT count(*) FROM databasechangelog;'"
            }
        }

        stage('Rollback Support (Manual Trigger Only)') {
            when {
                expression { return false }   // disable by default for safety
            }
            steps {
                sh "${LIQUIBASE} rollbackCount 1 --defaultsFile=${PROPS}"
            }
        }
    }

    post {

        success {
            echo "PIPELINE SUCCESS: Schema migration completed"
            sh "psql -U ${DB_USER} -d appdb -c 'SELECT * FROM databasechangelog ORDER BY dateexecuted DESC LIMIT 5;'"
        }

        failure {
            echo "PIPELINE FAILED: Checking Liquibase status"
            sh "${LIQUIBASE} status --defaultsFile=${PROPS} || true"
            sh "${LIQUIBASE} list-locks --defaultsFile=${PROPS} || true"
        }

        always {
            echo "Pipeline execution completed"
        }
    }
}
