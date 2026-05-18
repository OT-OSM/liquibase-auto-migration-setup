pipeline {

    agent any

    options {
        timestamps()
        disableConcurrentBuilds()
    }

    parameters {

        choice(
            name: 'ACTION',
            choices: [
                'VALIDATE',
                'UPDATESQL',
                'UPDATE',
                'ROLLBACK_COUNT',
                'ROLLBACK_TAG',
                'ROLLBACK_CHANGESET'
            ],
            description: 'Liquibase operation'
        )

        choice(
            name: 'ENVIRONMENT',
            choices: ['DEV', 'STAGING', 'PRODUCTION'],
            description: 'Target environment'
        )

        string(name: 'ROLLBACK_COUNT', defaultValue: '1')
        string(name: 'ROLLBACK_TAG', defaultValue: '')
        string(name: 'CHANGESET_ID', defaultValue: '')
        string(name: 'CHANGESET_AUTHOR', defaultValue: '')
    }

    environment {

        REMOTE_HOST = "18.216.116.201"
        REMOTE_USER = "ubuntu"

        DB_HOST = "localhost"
        DB_NAME = "appdb"
        DB_USER = "admin"
        DB_PASS = "admin"

        WORKDIR = "/home/ubuntu/liquibase-enterprise-poc"
        LIQUIBASE_CMD = "./liquibase"
    }

    stages {

        stage('Audit') {
            steps {
                script {

                    env.TRIGGERED_BY =
                        currentBuild.getBuildCauses()[0]?.userId ?: "Unknown User"

                    env.AUDIT = """
================ DB CHANGE AUDIT ================

User        : ${env.TRIGGERED_BY}
Action      : ${params.ACTION}
Environment : ${params.ENVIRONMENT}

Rollback Count : ${params.ROLLBACK_COUNT}
Rollback Tag   : ${params.ROLLBACK_TAG}

Job         : ${env.JOB_NAME}
Build       : ${env.BUILD_NUMBER}
URL         : ${env.BUILD_URL}

=================================================
"""

                    echo env.AUDIT
                }
            }
        }

        stage('Policy Engine') {
            steps {
                script {

                    env.RISK = "LOW"

                    if (params.ENVIRONMENT == 'STAGING') env.RISK = "MEDIUM"
                    if (params.ENVIRONMENT == 'PRODUCTION') env.RISK = "HIGH"
                    if (params.ACTION.contains("ROLLBACK")) env.RISK = "HIGH"

                    echo "Risk Level: ${env.RISK}"
                }
            }
        }

        stage('SQL Governance Validation') {

            steps {

                script {

                    def POLICY = [
                        DEV: [
                            truncate: "WARN",
                            unsafeUpdate: "WARN",
                            unsafeDelete: "WARN",
                            dropTable: "WARN"
                        ],
                        STAGING: [
                            truncate: "WARN",
                            unsafeUpdate: "FAIL",
                            unsafeDelete: "FAIL",
                            dropTable: "WARN"
                        ],
                        PRODUCTION: [
                            truncate: "FAIL",
                            unsafeUpdate: "FAIL",
                            unsafeDelete: "FAIL",
                            dropTable: "FAIL"
                        ]
                    ]

                    def checkRule = { rule, message, file ->

                        def action = POLICY[params.ENVIRONMENT][rule]

                        if (action == "FAIL") {
                            error("${message} in ${file}")
                        }

                        if (action == "WARN") {
                            echo "WARNING: ${message} in ${file}"
                            env.RISK = "HIGH"
                        }
                    }

                    def files = sh(
                        script: "find . \\( -name '*.sql' -o -name '*.xml' \\)",
                        returnStdout: true
                    ).trim().split("\n")

                    files.each { file ->

                        if (!file?.trim()) return

                        echo "Scanning: ${file}"

                        def content = readFile(file).toLowerCase()
                        def isXML = file.endsWith(".xml")

                        if (content.contains("create table"))
                            echo "CREATE TABLE detected"

                        if (content.contains("create index"))
                            echo "CREATE INDEX detected"

                        if (content.contains("primary key") ||
                            content.contains("foreign key") ||
                            content.contains("constraint"))
                            echo "CONSTRAINT detected"

                        if (content.contains("alter") ||
                            content.contains("modify") ||
                            content.contains("datatype")) {

                            echo "ALTER/MODIFY detected"

                            if (params.ENVIRONMENT != 'DEV') {
                                input message: "ALTER detected in ${file}. Approve?"
                            }
                        }

                        if (content.contains("drop table")) {
                            checkRule("dropTable", "DROP TABLE detected", file)
                        }

                        if (content.contains("drop column")) {
                            input message: "DROP COLUMN detected in ${file}. Approve?"
                        }

                        if (content.contains("truncate")) {
                            echo "TRUNCATE detected in ${file}"
                            checkRule("truncate", "TRUNCATE detected", file)
                        }

                        def unsafeUpdate =
                            content.contains("update") &&
                            content.contains(" set ") &&
                            !content.contains(" where ")

                        if (unsafeUpdate) {
                            checkRule("unsafeUpdate", "Unsafe UPDATE without WHERE", file)
                        }

                        def unsafeDelete =
                            content.contains("delete from") &&
                            !content.contains(" where ")

                        if (unsafeDelete) {
                            checkRule("unsafeDelete", "Unsafe DELETE without WHERE", file)
                        }

                        if (content.contains("procedure")) {
                            echo "PROCEDURE detected"

                            if (params.ENVIRONMENT == 'PRODUCTION') {
                                input message: "Stored Procedure in PROD. Approve?"
                            }
                        }

                        if (content.contains("function"))
                            echo "FUNCTION detected"

                        if (isXML &&
                            content.contains("<changeset") &&
                            !content.contains("<rollback>")) {

                            error("""
Rollback missing in ${file}

All Liquibase changesets MUST include rollback.
""")
                        }
                    }
                }
            }
        }

        stage('Production Safeguards') {
            when { expression { params.ENVIRONMENT == 'PRODUCTION' } }

            steps {
                script {

                    if (params.ACTION.startsWith("ROLLBACK")) {
                        error("Rollback blocked in PROD")
                    }

                    input message: "Confirm PROD deployment (CAB approval required)"
                }
            }
        }

        stage('Approval Gate') {
            when { expression { params.ENVIRONMENT != 'DEV' } }

            steps {
                timeout(time: 60, unit: 'MINUTES') {
                    input message: "Approve deployment?"
                }
            }
        }

        stage('Database Backup') {
            when { expression { params.ENVIRONMENT == 'PRODUCTION' } }

            steps {
                sshagent(credentials: ['liquibase-ci-key']) {
                    sh """
                    ssh ${REMOTE_USER}@${REMOTE_HOST} '
                        mkdir -p ${WORKDIR}/backup
                        export PGPASSWORD=${DB_PASS}

                        pg_dump -h ${DB_HOST} -U ${DB_USER} ${DB_NAME} \
                        > ${WORKDIR}/backup/backup_\$(date +%F_%H-%M-%S).sql
                    '
                    """
                }
            }
        }

        stage('Deploy') {

            steps {
                sshagent(credentials: ['liquibase-ci-key']) {

                    sh """
                    ssh ${REMOTE_USER}@${REMOTE_HOST} '
                        set -e
                        cd ${WORKDIR}

                        echo "${env.AUDIT}"

                        if [ "${params.ACTION}" = "VALIDATE" ]; then
                            ${LIQUIBASE_CMD} validate

                        elif [ "${params.ACTION}" = "UPDATESQL" ]; then
                            ${LIQUIBASE_CMD} updateSQL

                        elif [ "${params.ACTION}" = "UPDATE" ]; then
                            ${LIQUIBASE_CMD} validate
                            ${LIQUIBASE_CMD} updateSQL
                            ${LIQUIBASE_CMD} update

                        elif [ "${params.ACTION}" = "ROLLBACK_COUNT" ]; then
                            ${LIQUIBASE_CMD} rollbackCount ${params.ROLLBACK_COUNT}

                        elif [ "${params.ACTION}" = "ROLLBACK_TAG" ]; then
                            ${LIQUIBASE_CMD} rollback ${params.ROLLBACK_TAG}

                        elif [ "${params.ACTION}" = "ROLLBACK_CHANGESET" ]; then
                            ${LIQUIBASE_CMD} rollbackOneChangeSet \
                            --changesetId=${params.CHANGESET_ID} \
                            --changesetAuthor=${params.CHANGESET_AUTHOR}
                        fi

                        ${LIQUIBASE_CMD} history
                    '
                    """
                }
            }
        }
    }

    post {

        success {
            echo "DEPLOYMENT SUCCESS"
        }

        failure {
            echo "DEPLOYMENT FAILED"
        }

        always {
            archiveArtifacts artifacts: '**/*.log', allowEmptyArchive: true
        }
    }
}
