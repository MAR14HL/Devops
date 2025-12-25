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
                            
                            # Décoder le kubeconfig
                            echo "$KUBECONFIG_BASE64" | base64 -d > $KUBECONFIG_FILE
                            
                            export KUBECONFIG=$KUBECONFIG_FILE
                            
                            echo "=== Vérification du fichier kubeconfig ==="
                            ls -la $KUBECONFIG_FILE
                            
                            echo "=== Test connexion Kubernetes ==="
                            kubectl version --client
                            kubectl cluster-info
                            kubectl get nodes
                            
                            echo "=== Création namespace devops ==="
                            kubectl get namespace devops || kubectl create namespace devops
                            
                            echo "=== Déploiement MySQL (Secret + PVC + Deployment + Service) ==="
                            kubectl apply -f mysql-deployment.yaml -n devops
                            
                            echo "=== Vérification des ressources créées ==="
                            kubectl get secret mysql-secret -n devops || echo "⚠️  Secret non créé"
                            kubectl get pvc mysql-pvc -n devops || echo "⚠️  PVC non créé"
                            kubectl get deployment mysql -n devops || echo "⚠️  Deployment non créé"
                            kubectl get svc mysql-service -n devops || echo "⚠️  Service non créé"
                            
                            echo "=== Attente PVC Bound ==="
                            kubectl wait --for=jsonpath='{.status.phase}'=Bound pvc/mysql-pvc -n devops --timeout=60s || {
                                echo "⚠️  PVC pas encore Bound"
                                kubectl describe pvc mysql-pvc -n devops
                            }
                            
                            echo "=== Attente MySQL Ready (max 5min) ==="
                            kubectl wait --for=condition=ready pod -l app=mysql -n devops --timeout=300s || {
                                echo "❌ MySQL n'est pas prêt"
                                kubectl get pods -l app=mysql -n devops
                                kubectl describe pods -l app=mysql -n devops
                                kubectl get pvc -n devops
                                kubectl get events -n devops --sort-by='. lastTimestamp' | tail -20
                                exit 1
                            }
                            
                            echo "✅ MySQL est prêt !"
                            
                            echo "=== Déploiement Spring App ==="
                            kubectl apply -f spring-deployment.yaml -n devops
                            
                            echo "=== Mise à jour de l'image Spring App ==="
                            kubectl set image deployment/spring-app spring-app=${IMAGE_NAME}:${IMAGE_TAG} -n devops
                            
                            echo "=== Attente déploiement Spring App ==="
                            kubectl rollout status deployment/spring-app -n devops --timeout=300s
                            
                            echo "=== Vérification finale ==="
                            kubectl get all -n devops
                            kubectl get pvc -n devops
                            
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
                            echo "$KUBECONFIG_BASE64" | base64 -d > $KUBECONFIG_FILE
                            export KUBECONFIG=$KUBECONFIG_FILE
                            
                            echo "=== Ressources Kubernetes ==="
                            kubectl get all -n ${K8S_NAMESPACE}
                            
                            echo "=== Logs Spring App (30 dernières lignes) ==="
                            kubectl logs deployment/spring-app -n ${K8S_NAMESPACE} --tail=30 || echo "Pas de logs disponibles"
                            
                            echo "=== URL du service ==="
                            NODE_PORT=$(kubectl get svc spring-service -n ${K8S_NAMESPACE} -o jsonpath='{.spec.ports[0].nodePort}')
                            echo "Application accessible sur:  http://<MINIKUBE-IP>:$NODE_PORT"
                            
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
            echo "Pour accéder à l'application: minikube service spring-service -n ${K8S_NAMESPACE}"
        }
        failure {
            echo "❌ Pipeline échoué"
            script {
                sh '''
                    echo "=== Debug Info ==="
                    docker images | grep student-management || true
                    
                    KUBECONFIG_FILE=$(mktemp)
                    echo "$KUBECONFIG_BASE64" | base64 -d > $KUBECONFIG_FILE 2>/dev/null || true
                    export KUBECONFIG=$KUBECONFIG_FILE
                    
                    kubectl get all -n devops 2>/dev/null || echo "Kubernetes non accessible"
                    kubectl get events -n devops --sort-by='. lastTimestamp' | tail -20 || true
                    
                    rm -f $KUBECONFIG_FILE
                '''
            }
        }
        always {
            echo "Pipeline terminé - Build #${BUILD_NUMBER}"
            sh 'rm -f /tmp/tmp. * 2>/dev/null || true'
        }
    }
}
