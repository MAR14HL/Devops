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
        withCredentials([string(credentialsId: 'kubeconfig-minikube', variable: 'KUBECONFIG_TEXT')]) {
            script {
                // Créer un fichier temporaire kubeconfig
                sh '''
                    echo "$KUBECONFIG_TEXT" > /tmp/kubeconfig
                    export KUBECONFIG=/tmp/kubeconfig

                    echo "Vérification des nodes"
                    kubectl get nodes

                    echo "Création namespace devops si nécessaire"
                    kubectl get namespace devops || kubectl create namespace devops

                    echo "Déploiement MySQL"
                    kubectl apply -f mysql-deployment.yaml -n devops --validate=false

                    echo "Attente MySQL Running..."
                    timeout 300 bash -c 'until kubectl get pod -l app=mysql -n devops -o jsonpath="{.items[0].status.phase}" | grep -q Running; do echo "Waiting MySQL..."; sleep 5; done'

                    echo "Déploiement Spring App"
                    kubectl apply -f spring-deployment.yaml -n devops --validate=false
                    kubectl rollout status deployment/spring-app -n devops --timeout=300s

                    echo "Vérification finale"
                    kubectl get all -n devops
                '''
            }
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
