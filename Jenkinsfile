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
                    url: 'https://github.com/MAR14HL/Devops. git',
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
                        -Dsonar. projectKey=${APP_NAME} \
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
                    sh "docker tag ${IMAGE_NAME}:${IMAGE_TAG} ${IMAGE_NAME}: latest"
                }
            }
        }

        stage('Docker Push') {
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'dockerhub-creds',
                    usernameVariable: 'DOCKER_USER',
                    passwordVariable:  'DOCKER_PASS'
                )]) {
                    sh """
                        echo "\$DOCKER_PASS" | docker login -u "\$DOCKER_USER" --password-stdin
                        docker push ${IMAGE_NAME}:${IMAGE_TAG}
                        docker push ${IMAGE_NAME}:latest
                    """
                }
            }
        }

        stage('Deploy to Kubernetes') {
            steps {
                script {
                    // Utilise le plugin Kubernetes CLI si installé
                    // Sinon, utilise withCredentials
                    try {
                        withKubeConfig([credentialsId: 'kubeconfig-minikube']) {
                            sh '''
                                kubectl get nodes
                                kubectl get namespace devops || kubectl create namespace devops
                                kubectl apply -f mysql-deployment.yaml -n devops
                                kubectl wait --for=condition=ready pod -l app=mysql -n devops --timeout=300s
                                kubectl apply -f spring-deployment.yaml -n devops
                                kubectl set image deployment/spring-app spring-app=${IMAGE_NAME}:${IMAGE_TAG} -n devops
                                kubectl rollout status deployment/spring-app -n devops --timeout=300s
                                kubectl get all -n devops
                            '''
                        }
                    } catch (Exception e) {
                        echo "Plugin Kubernetes CLI non disponible, utilisation de la méthode alternative"
                        withCredentials([file(credentialsId: 'kubeconfig-minikube', variable: 'KUBECONFIG')]) {
                            sh '''
                                kubectl get nodes
                                kubectl get namespace devops || kubectl create namespace devops
                                kubectl apply -f mysql-deployment.yaml -n devops
                                kubectl wait --for=condition=ready pod -l app=mysql -n devops --timeout=300s
                                kubectl apply -f spring-deployment.yaml -n devops
                                kubectl set image deployment/spring-app spring-app=${IMAGE_NAME}:${IMAGE_TAG} -n devops
                                kubectl rollout status deployment/spring-app -n devops --timeout=300s
                                kubectl get all -n devops
                            '''
                        }
                    }
                }
            }
        }

        stage('Verification') {
            steps {
                script {
                    try {
                        withKubeConfig([credentialsId: 'kubeconfig-minikube']) {
                            sh '''
                                kubectl get all -n ${K8S_NAMESPACE}
                                kubectl logs deployment/spring-app -n ${K8S_NAMESPACE} --tail=30
                                minikube service spring-service -n ${K8S_NAMESPACE} --url || kubectl get svc -n ${K8S_NAMESPACE}
                            '''
                        }
                    } catch (Exception e) {
                        withCredentials([file(credentialsId: 'kubeconfig-minikube', variable: 'KUBECONFIG')]) {
                            sh '''
                                kubectl get all -n ${K8S_NAMESPACE}
                                kubectl logs deployment/spring-app -n ${K8S_NAMESPACE} --tail=30
                                minikube service spring-service -n ${K8S_NAMESPACE} --url || kubectl get svc -n ${K8S_NAMESPACE}
                            '''
                        }
                    }
                }
            }
        }
    }

    post {
        success {
            echo "🚀 Déploiement réussi !"
            echo "Image:  ${IMAGE_NAME}:${IMAGE_TAG}"
        }
        failure {
            echo "❌ Pipeline échoué"
        }
        always {
            cleanWs(deleteDirs: true)
        }
    }
}
