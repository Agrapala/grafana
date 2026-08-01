pipeline {
	agent any

	options {
		timestamps()
		disableConcurrentBuilds()
	}

	environment {
		ANSIBLE_HOST_KEY_CHECKING = 'False'

	}

	stages {
		stage('Checkout') {
			steps {
				checkout scm
			}
		}

		stage('Run Ansible deployment') {
			steps {
				sh '''
                    #!/bin/bash
                    set -euo pipefail

                    ansible-playbook -i ansible/inventory.ini ansible/finalbook.yml

                '''
			}
		}
	}

	post {
		success {
			echo 'Monitoring stack deployed through Ansible.'
		}
		failure {
			echo 'Deployment failed. Check Ansible access, Docker availability, and firewall access on both servers.'
		}
        always {
            echo 'Cleaning up workspace...'
            cleanWs()
        }
	}
}
