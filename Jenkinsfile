pipeline {
    agent any

    environment {
        MAVEN_HOME = "/usr/share/maven"
        IMAGE_NAME = "soulaima13/student-management"
        IMAGE_TAG = "${BUILD_NUMBER}"
        K8S_NAMESPACE = "devops"
        APP_NAME = "spring-app"
    }

    stages {

        stage('Checkout') {
            steps {
                git branch: 'main',
                    url: 'https://github.com/MAR14HL/Devops.git',
                    credentialsId: 'github-token'
            }
        }

        stage('Build Maven') {
            steps {
                sh 'mvn clean package -DskipTests'
            }
        }

        stage('SonarQube Analysis') {
            steps {
                withCredentials([string(credentialsId: 'sonar-token', variable: 'SONAR_TOKEN')]) {
                    sh """
                        ${MAVEN_HOME}/bin/mvn sonar:sonar \
                        -Dsonar.projectKey=${APP_NAME} \
                        -Dsonar.host.url=http://localhost:9000 \
                        -Dsonar.login=${SONAR_TOKEN}
                    """
                }
            }
        }

        stage('Archive Jar') {
            steps {
                archiveArtifacts artifacts: 'target/*.jar', fingerprint: true
            }
        }

        stage('Docker Build') {
            steps {
                script {
                    if (!fileExists("Dockerfile")) {
                        sh '''
                        cat > Dockerfile << 'EOF'
FROM openjdk:17-jdk-slim
WORKDIR /app
COPY target/*.jar app.jar
EXPOSE 8089
ENTRYPOINT ["java", "-jar", "app.jar"]
EOF
                        '''
                    }

                    sh "docker build -t ${IMAGE_NAME}:${IMAGE_TAG} ."
                    sh "docker tag ${IMAGE_NAME}:${IMAGE_TAG} ${IMAGE_NAME}:latest"
                }
            }
        }

        stage('Docker Push') {
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'dockerhub-creds',
                    usernameVariable: 'DOCKER_USER',
                    passwordVariable: 'DOCKER_PASS'
                )]) {
                    sh """
                        echo "$DOCKER_PASS" | docker login -u "$DOCKER_USER" --password-stdin
                        docker push ${IMAGE_NAME}:${IMAGE_TAG}
                        docker push ${IMAGE_NAME}:latest
                    """
                }
            }
        }

        // ===================== KUBERNETES =====================
        stage('Deploy to Kubernetes') {
            steps {
                script {
                    echo "Création Namespace"
                    sh """
                        kubectl get namespace ${K8S_NAMESPACE} || kubectl create namespace ${K8S_NAMESPACE}
                    """

                    echo "Mise à jour de l'image dans spring-deployment.yaml"
                    sh """
                        sed -i 's|image: .*|image: ${IMAGE_NAME}:${IMAGE_TAG}|' spring-deployment.yaml
                    """

                    echo "Déploiement MySQL"
                    sh """
                        kubectl apply -f mysql-deployment.yaml -n ${K8S_NAMESPACE} --validate=false
                    """

                    echo "Attente MySQL Running..."
                    sh """
                        timeout 300 bash -c 'until kubectl get pod -l app=mysql -n ${K8S_NAMESPACE} -o jsonpath="{.items[0].status.phase}" | grep -q Running; do echo "Waiting MySQL..."; sleep 5; done'
                    """

                    echo "Déploiement Spring App"
                    sh """
                        kubectl apply -f spring-deployment.yaml -n ${K8S_NAMESPACE} --validate=false
                        kubectl rollout status deployment/spring-app -n ${K8S_NAMESPACE} --timeout=300s
                    """
                }
            }
        }

        stage('Verification') {
            steps {
                script {
                    sh """
                        kubectl get all -n ${K8S_NAMESPACE}
                        kubectl logs deployment/spring-app -n ${K8S_NAMESPACE} --tail=30
                        minikube service spring-service -n ${K8S_NAMESPACE} --url || true
                    """
                }
            }
        }
    }

    post {
        success {
            echo "🚀 Déploiement réussi !"
        }
        failure {
            echo "❌ Pipeline échoué"
        }
    }
}
