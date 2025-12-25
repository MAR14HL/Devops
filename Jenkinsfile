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
                        ${MAVEN_HOME}/bin/mvn -B sonar:sonar \
                            -Dsonar.projectKey=${APP_NAME} \
                            -Dsonar.host.url=http://localhost:9000 \
                            -Dsonar.login=${SONAR_TOKEN}
                    """
                }
            }
        }

        stage('Archive Jar') {
            steps {
                archiveArtifacts artifacts:  'target/*.jar', fingerprint: true
            }
        }

        stage('Docker Build') {
            steps {
                script {
                    // Vérifier si Dockerfile existe
                    sh 'ls -la Dockerfile || echo "Création de Dockerfile..."'

                    // Créer Dockerfile si nécessaire
                    sh '''
                        if [ ! -f Dockerfile ]; then
                            cat > Dockerfile << 'EOF'
FROM openjdk:17-jdk-slim
WORKDIR /app
COPY target/*.jar app.jar
EXPOSE 8089
ENTRYPOINT ["java", "-jar", "app.jar"]
EOF
                        fi
                    '''

                    // Build Docker
                    sh "docker build -t ${IMAGE_NAME}:${IMAGE_TAG} ."
                    sh "docker tag ${IMAGE_NAME}:${IMAGE_TAG} ${IMAGE_NAME}:latest"
                }
            }
        }

        stage('Docker Push') {
            steps {
                withCredentials([usernamePassword(
                    credentialsId:  'dockerhub-creds',
                    usernameVariable: 'DOCKER_USER',
                    passwordVariable: 'DOCKER_PASS'
                )]) {
                    sh '''
                        echo "$DOCKER_PASS" | docker login -u "$DOCKER_USER" --password-stdin
                        docker push ${IMAGE_NAME}:${IMAGE_TAG}
                        docker push ${IMAGE_NAME}:latest
                        docker logout
                    '''
                }
            }
        }

        stage('Deploy to Kubernetes') {
            steps {
                withCredentials([string(credentialsId: 'kubeconfig-minikube', variable: 'KUBECONFIG_BASE64')]) {
                    script {
                        sh '''
                            # Créer un fichier temporaire sécurisé
                            KUBECONFIG_FILE=$(mktemp)
                            
                            # Décoder le kubeconfig (essayer avec et sans base64)
                            echo "$KUBECONFIG_BASE64" | base64 -d > $KUBECONFIG_FILE 2>/dev/null || echo "$KUBECONFIG_BASE64" > $KUBECONFIG_FILE
                            
                            export KUBECONFIG=$KUBECONFIG_FILE
                            
                            echo "=== Vérification du fichier kubeconfig ==="
                            ls -la $KUBECONFIG_FILE
                            
                            echo "=== Test connexion Kubernetes ==="
                            kubectl version --client
                            kubectl cluster-info
                            kubectl get nodes
                            
                            echo "=== Création namespace devops ==="
                            kubectl get namespace devops || kubectl create namespace devops
                            
                            echo "=== Déploiement MySQL ==="
                            kubectl apply -f mysql-deployment.yaml -n devops
                            
                            echo "=== Attente MySQL Ready ==="
                            kubectl wait --for=condition=ready pod -l app=mysql -n devops --timeout=300s || {
                                echo "MySQL pods status:"
                                kubectl get pods -l app=mysql -n devops
                                kubectl describe pods -l app=mysql -n devops
                                exit 1
                            }
                            
                            echo "=== Déploiement Spring App ==="
                            kubectl apply -f spring-deployment.yaml -n devops
                            
                            echo "=== Mise à jour de l'image ==="
                            kubectl set image deployment/spring-app spring-app=${IMAGE_NAME}:${IMAGE_TAG} -n devops
                            
                            echo "=== Attente déploiement ==="
                            kubectl rollout status deployment/spring-app -n devops --timeout=300s
                            
                            echo "=== Vérification finale ==="
                            kubectl get all -n devops
                            
                            # Nettoyage
                            rm -f $KUBECONFIG_FILE
                        '''
                    }
                }
            }
        }

        stage('Verification') {
            steps {
                withCredentials([string(credentialsId: 'kubeconfig-minikube', variable: 'KUBECONFIG_BASE64')]) {
                    script {
                        sh '''
                            KUBECONFIG_FILE=$(mktemp)
                            echo "$KUBECONFIG_BASE64" | base64 -d > $KUBECONFIG_FILE 2>/dev/null || echo "$KUBECONFIG_BASE64" > $KUBECONFIG_FILE
                            export KUBECONFIG=$KUBECONFIG_FILE
                            
                            echo "=== Ressources Kubernetes ==="
                            kubectl get all -n ${K8S_NAMESPACE}
                            
                            echo "=== Logs Spring App (30 dernières lignes) ==="
                            kubectl logs deployment/spring-app -n ${K8S_NAMESPACE} --tail=30 || echo "Pas de logs disponibles"
                            
                            echo "=== URL du service ==="
                            minikube service spring-service -n ${K8S_NAMESPACE} --url || kubectl get svc spring-service -n ${K8S_NAMESPACE}
                            
                            rm -f $KUBECONFIG_FILE
                        '''
                    }
                }
            }
        }
    }

    post {
        success {
            echo "🚀 Déploiement réussi !"
            echo "Image déployée:  ${IMAGE_NAME}:${IMAGE_TAG}"
        }
        failure {
            echo "❌ Pipeline échoué"
            script {
                sh '''
                    echo "=== Debug Info ==="
                    docker images | grep student-management || true
                    kubectl get all -n devops 2>/dev/null || echo "Kubernetes non accessible"
                '''
            }
        }
        always {
            echo "Pipeline terminé - Build #${BUILD_NUMBER}"
            cleanWs(deleteDirs: true, patterns: [[pattern: '/tmp/kubeconfig*', type:  'INCLUDE']])
        }
    }
}
