pipeline {
    agent any

    environment {
        REMOTE_HOST = "172.31.16.197"
        REMOTE_USER = "ubuntu"

        DB_HOST = "localhost"
        DB_PORT = "5432"
        DB_NAME = "appdb"
        DB_USER = "admin"
        DB_PASS = "admin"

        WORKDIR = "/home/ubuntu/liquibase-enterprise-poc"
    }

    stages {

        stage('Run Liquibase on EC2 Server') {

            steps {

                sshagent(credentials: ['liquibase-ci-key']) {

                    sh """
                    ssh -T -o StrictHostKeyChecking=no ${REMOTE_USER}@${REMOTE_HOST} '
                        set -e

                        echo "========================================="
                        echo "Connected to Liquibase EC2 Server"
                        echo "========================================="

                        whoami
                        hostname

                        echo "========================================="
                        echo "Move to Liquibase directory"
                        echo "========================================="

                        cd ${WORKDIR}

                        pwd
                        ls -lah

                        echo "========================================="
                        echo "Liquibase Version"
                        echo "========================================="

                        ./liquibase --version

                        echo "========================================="
                        echo "Postgres Connectivity Check"
                        echo "========================================="

                        PGPASSWORD=${DB_PASS} psql \
                          -h ${DB_HOST} \
                          -U ${DB_USER} \
                          -d ${DB_NAME} \
                          -c "\\\\dt"

                        echo "========================================="
                        echo "Liquibase Validate"
                        echo "========================================="

                        ./liquibase validate \
                          --defaultsFile=liquibase.properties

                        echo "========================================="
                        echo "Check Existing Locks"
                        echo "========================================="

                        ./liquibase list-locks \
                          --defaultsFile=liquibase.properties || true

                        echo "========================================="
                        echo "Release Locks"
                        echo "========================================="

                        ./liquibase release-locks \
                          --defaultsFile=liquibase.properties || true

                        echo "========================================="
                        echo "Deploy Schema"
                        echo "========================================="

                        ./liquibase update \
                          --defaultsFile=liquibase.properties

                        echo "========================================="
                        echo "Verify users table"
                        echo "========================================="

                        PGPASSWORD=${DB_PASS} psql \
                          -h ${DB_HOST} \
                          -U ${DB_USER} \
                          -d ${DB_NAME} \
                          -c "\\\\d users"

                        echo "========================================="
                        echo "Liquibase History"
                        echo "========================================="

                        ./liquibase history \
                          --defaultsFile=liquibase.properties

                        echo "========================================="
                        echo "databasechangelog count"
                        echo "========================================="

                        PGPASSWORD=${DB_PASS} psql \
                          -h ${DB_HOST} \
                          -U ${DB_USER} \
                          -d ${DB_NAME} \
                          -c "SELECT count(*) FROM databasechangelog;"

                        echo "========================================="
                        echo "Liquibase Deployment SUCCESS"
                        echo "========================================="
                    '
                    """
                }
            }
        }
    }

    post {

        success {
            echo 'SUCCESS: Liquibase deployment completed successfully'
        }

        failure {
            echo 'FAILED: Liquibase deployment failed'
        }

        always {
            echo 'Pipeline execution finished'
        }
    }
}
