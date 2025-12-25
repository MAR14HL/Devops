pipeline {
    agent any

    environment {
        MAVEN_HOME = "/usr/share/maven"
        IMAGE_NAME = "soulaima13/student-management"  // Changé pour votre app
        IMAGE_TAG = "${BUILD_NUMBER}"
        K8S_NAMESPACE = "devops"
        APP_NAME = "student-management"
    }

    stages {

        stage('Checkout') {
               steps {
                    git branch: 'main',
                        url: 'https://github.com/MAR14HL/Devops.git',
                        credentialsId: 'github-token'
                }
        }

        stage('Build') {
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

        stage('Archive Artifacts') {
            steps {
                archiveArtifacts artifacts: 'target/*.jar', fingerprint: true
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
EXPOSE 8080
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
                    credentialsId: 'dockerhub-creds',
                    usernameVariable: 'DOCKER_USER',
                    passwordVariable: 'DOCKER_PASS'
                )]) {
                    sh """
                        echo "$DOCKER_PASS" | docker login -u "$DOCKER_USER" --password-stdin
                        docker push ${IMAGE_NAME}:${IMAGE_TAG}
                        docker push ${IMAGE_NAME}:latest
                        docker logout
                    """
                }
            }
        }

        // ========== DÉPLOIEMENT KUBERNETES ==========
        stage('Prepare Kubernetes Files') {
            steps {
                script {
                    // Vérifier que les fichiers YAML existent
                    sh '''
                        echo "Vérification des fichiers YAML..."
                        ls -la *.yaml || echo "Aucun fichier YAML trouvé"
                    '''

                    // Modifier student-deployment.yaml pour utiliser la bonne image
                    sh """
                        sed -i 's|image:.*|image: ${IMAGE_NAME}:${IMAGE_TAG}|' student-deployment.yaml || true
                    """
                }
            }
        }

        stage('Deploy to Kubernetes') {
            steps {
                script {
                    // 1. Créer le namespace
                    sh """
                        kubectl create namespace ${K8S_NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -
                    """

                    // 2. Déployer MySQL (uniquement si pas déjà déployé)
                    sh """
                        echo "Déploiement MySQL..."
                        kubectl apply -f mysql-pv.yaml -n ${K8S_NAMESPACE} --dry-run=client && kubectl apply -f mysql-pv.yaml -n ${K8S_NAMESPACE} || echo "PV déjà existant"
                        kubectl apply -f mysql-pvc.yaml -n ${K8S_NAMESPACE} --dry-run=client && kubectl apply -f mysql-pvc.yaml -n ${K8S_NAMESPACE} || echo "PVC déjà existant"
                        kubectl apply -f mysql-deployment.yaml -n ${K8S_NAMESPACE} --dry-run=client && kubectl apply -f mysql-deployment.yaml -n ${K8S_NAMESPACE} || echo "MySQL déjà déployé"
                        kubectl apply -f mysql-service.yaml -n ${K8S_NAMESPACE} --dry-run=client && kubectl apply -f mysql-service.yaml -n ${K8S_NAMESPACE} || echo "Service MySQL déjà existant"
                    """

                    // 3. Attendre MySQL
                    sh """
                        timeout 300 bash -c 'until kubectl get pod -l app=mysql -n ${K8S_NAMESPACE} -o jsonpath="{.items[0].status.phase}" 2>/dev/null | grep -q Running; do sleep 5; echo "En attente de MySQL..."; done'
                    """

                    // 4. Déployer l'application
                    sh """
                        echo "Déploiement de l'application..."
                        kubectl apply -f student-configmap.yaml -n ${K8S_NAMESPACE}
                        kubectl apply -f student-secret.yaml -n ${K8S_NAMESPACE}
                        kubectl apply -f student-deployment.yaml -n ${K8S_NAMESPACE}
                        kubectl apply -f student-service.yaml -n ${K8S_NAMESPACE}
                    """

                    // 5. Vérifier le déploiement
                    sh """
                        kubectl rollout status deployment/student-app -n ${K8S_NAMESPACE} --timeout=300s
                    """
                }
            }
        }

        stage('Health Check & Verification') {
            steps {
                script {
                    // Afficher l'état
                    sh """
                        echo "=== État du déploiement ==="
                        kubectl get all -n ${K8S_NAMESPACE}
                        echo ""
                        echo "=== Logs de l'application ==="
                        kubectl logs deployment/student-app -n ${K8S_NAMESPACE} --tail=20
                        echo ""
                        echo "=== Test MySQL ==="
                        kubectl exec deployment/mysql -n ${K8S_NAMESPACE} -- mysql -u root -proot123 -e "SHOW DATABASES;" || echo "MySQL test échoué"
                    """

                    // Obtenir l'URL
                    sh """
                        echo "=== URL de l'application ==="
                        minikube service student-service -n ${K8S_NAMESPACE} --url || echo "Utilisez: http://\$(minikube ip):30080"
                    """
                }
            }
        }
    }

    post {
        success {
            script {
                echo "✅✅✅ DÉPLOIEMENT RÉUSSI ! ✅✅✅"
                echo "📦 Image: ${IMAGE_NAME}:${IMAGE_TAG}"
                echo "🚀 Namespace: ${K8S_NAMESPACE}"
                echo "🌐 URL: http://\$(minikube ip):30080"
                echo ""
                echo "Commandes de vérification:"
                echo "  kubectl get all -n ${K8S_NAMESPACE}"
                echo "  minikube service student-service -n ${K8S_NAMESPACE} --url"
                echo "  kubectl logs deployment/student-app -n ${K8S_NAMESPACE}"
            }

            // Notification optionnelle
            // emailext to: 'team@example.com', subject: "Déploiement réussi: ${APP_NAME}", body: "Build ${BUILD_NUMBER} déployé avec succès"
        }

        failure {
            script {
                echo "❌❌❌ DÉPLOIEMENT ÉCHOUÉ ❌❌❌"
                echo "Derniers logs d'erreur:"
                sh """
                    kubectl describe deployment/student-app -n ${K8S_NAMESPACE} || true
                    kubectl get events -n ${K8S_NAMESPACE} --sort-by='.lastTimestamp' | tail -20 || true
                """
            }
        }

        always {
            // Nettoyage ou rapport
            echo "Build ${BUILD_NUMBER} terminé"
            // junit 'target/surefire-reports/*.xml'  // Pour les tests JUnit
        }
    }
}