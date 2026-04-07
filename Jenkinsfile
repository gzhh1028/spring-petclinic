pipeline {
    agent any
    
    environment {
        APP_NAME = 'spring-petclinic'
        HARBOR_URL = '172.21.196.15'
        K3S_IP = '172.21.196.16'
        IMAGE_TAG = "${env.BUILD_NUMBER}"
        DOCKER_IMAGE = "${HARBOR_URL}/library/${APP_NAME}:${IMAGE_TAG}"
    }
    
    stages {
        stage('拉取代码') {
            steps { checkout scm }
        }

        stage('编译打包') {
            steps {
                sh '''
                    chmod +x mvnw
                    ./mvnw clean package -DskipTests
                '''
            }
        }

        // ===================== 【关键修复：国内镜像，永不超时】 =====================
        stage('生成Dockerfile') {
            steps {
                sh '''
                    cat > Dockerfile << 'EOF'
FROM harbor.aliyuncs.com/library/openjdk:17-jre-slim
COPY target/*.jar app.jar
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "app.jar"]
EOF
                '''
            }
        }
        // ==========================================================================

        stage('传输文件到K3s') {
            environment {
                SSH_OPTS = '-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'
            }
            steps {
                sh """
                    ssh \${SSH_OPTS} root@${K3S_IP} "mkdir -p /opt/spring-petclinic"
                    scp \${SSH_OPTS} -r target/ root@${K3S_IP}:/opt/spring-petclinic/
                    scp \${SSH_OPTS} Dockerfile root@${K3S_IP}:/opt/spring-petclinic/
                """
            }
        }

        stage('在K3s构建镜像') {
            environment {
                SSH_OPTS = '-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'
            }
            steps {
                sh """
                    ssh \${SSH_OPTS} root@${K3S_IP} "cd /opt/spring-petclinic && docker build -t ${DOCKER_IMAGE} ."
                """
            }
        }

        stage('推送镜像') {
            environment {
                SSH_OPTS = '-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'
            }
            steps {
                withCredentials([usernamePassword(credentialsId: 'HARBOR_CRED', usernameVariable: 'HARBOR_USER', passwordVariable: 'HARBOR_PASS')]) {
                    sh """
                        ssh \${SSH_OPTS} root@${K3S_IP} "docker login ${HARBOR_URL} -u ${HARBOR_USER} -p ${HARBOR_PASS}"
                        ssh \${SSH_OPTS} root@${K3S_IP} "docker push ${DOCKER_IMAGE}"
                    """
                }
            }
        }

        stage('部署到K3s') {
            environment {
                SSH_OPTS = '-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'
            }
            steps {
                sh """
                    ssh \${SSH_OPTS} root@${K3S_IP} "kubectl apply -f - << EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: spring-petclinic
spec:
  replicas: 1
  selector:
    matchLabels:
      app: spring-petclinic
template:
  metadata:
    labels:
      app: spring-petclinic
  spec:
    containers:
    - name: spring-petclinic
      image: ${DOCKER_IMAGE}
      ports:
      - containerPort: 8080
---
apiVersion: v1
kind: Service
metadata:
  name: spring-petclinic
spec:
  selector:
    app: spring-petclinic
  ports:
  - port: 80
    targetPort: 8080
EOF"
                    ssh \${SSH_OPTS} root@${K3S_IP} "kubectl rollout restart deploy spring-petclinic"
                    sleep 10
                    ssh \${SSH_OPTS} root@${K3S_IP} "kubectl get pods"
                """
            }
        }
    }

    post {
        success { echo "✅ 部署成功！" }
        failure { echo "❌ 部署失败！" }
    }
}
