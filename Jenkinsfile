pipeline {
    agent any

    environment {
        LIQUIBASE = "/opt/liquibase/liquibase"

        DB_HOST = "localhost"
        DB_PORT = "5432"
        DB_NAME = "appdb"
        DB_USER = "admin"
        DB_PASS = "admin"

        PROPS = "liquibase.properties"
    }

    stages {

        stage('Workspace Check') {
            steps {
                sh 'echo "Workspace Contents:"'
                sh 'ls -R'
            }
        }

        stage('DB Connectivity Check (No Prompt)') {
            steps {
                sh """
                PGPASSWORD=${DB_PASS} psql -h ${DB_HOST} -U ${DB_USER} -d ${DB_NAME} -c '\\dt'
                """
            }
        }

        stage('Liquibase Validate') {
            steps {
                sh """
                ${LIQUIBASE} validate --defaultsFile=${PROPS}
                """
            }
        }

        stage('Check DB Lock (Safety Gate)') {
            steps {
                sh """
                ${LIQUIBASE} list-locks --defaultsFile=${PROPS} || true
                """
            }
        }

        stage('Release Lock (Auto-Recovery)') {
            steps {
                sh """
                ${LIQUIBASE} release-locks --defaultsFile=${PROPS} || true
                """
            }
        }

        stage('Deploy Schema (Incremental Migration)') {
            steps {
                sh """
                ${LIQUIBASE} update --defaultsFile=${PROPS}
                """
            }
        }

        stage('Post Deployment Verification') {
            steps {
                sh """
                PGPASSWORD=${DB_PASS} psql -h ${DB_HOST} -U ${DB_USER} -d ${DB_NAME} -c '\\d users'
                PGPASSWORD=${DB_PASS} psql -h ${DB_HOST} -U ${DB_USER} -d ${DB_NAME} -c 'SELECT * FROM users;'
                """
            }
        }

        stage('Audit Tracking (DATABASECHANGELOG)') {
            steps {
                sh """
                ${LIQUIBASE} history --defaultsFile=${PROPS}
                PGPASSWORD=${DB_PASS} psql -h ${DB_HOST} -U ${DB_USER} -d ${DB_NAME} -c 'SELECT COUNT(*) FROM databasechangelog;'
                PGPASSWORD=${DB_PASS} psql -h ${DB_HOST} -U ${DB_USER} -d ${DB_NAME} -c 'SELECT * FROM databasechangelog ORDER BY dateexecuted DESC LIMIT 5;'
                """
            }
        }

        stage('Rollback (Manual Control Only)') {
            when {
                expression { return false }
            }
            steps {
                sh """
                ${LIQUIBASE} rollbackCount 1 --defaultsFile=${PROPS}
                """
            }
        }
    }

    post {

        success {
            echo "PIPELINE SUCCESS: Migration completed successfully"

            sh """
            PGPASSWORD=${DB_PASS} psql -h ${DB_HOST} -U ${DB_USER} -d ${DB_NAME} -c 'SELECT count(*) FROM databasechangelog;'
            """
        }

        failure {
            echo "PIPELINE FAILED: Debugging Liquibase + DB state"

            sh """
            ${LIQUIBASE} status --defaultsFile=${PROPS} || true
            ${LIQUIBASE} list-locks --defaultsFile=${PROPS} || true
            """

            sh """
            PGPASSWORD=${DB_PASS} psql -h ${DB_HOST} -U ${DB_USER} -d ${DB_NAME} -c '\\dt' || true
            """
        }

        always {
            echo "Pipeline execution finished (audit-safe)"
        }
    }
}
