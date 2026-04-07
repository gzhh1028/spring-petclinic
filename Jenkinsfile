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
        // 1. 拉代码
        stage('拉取代码') {
            steps {
                checkout scm
            }
        }

        // 2. 编译（在 Jenkins 本机）
        stage('编译打包') {
            steps {
                sh '''
                    chmod +x mvnw
                    ./mvnw clean package -DskipTests
                '''
            }
        }

        // 3. 把代码传到 16 机器
        stage('传输文件到K3s主机') {
            steps {
                sh '''
                    scp -r target/ root@${K3S_IP}:/opt/spring-petclinic/
                    scp Dockerfile root@${K3S_IP}:/opt/spring-petclinic/
                '''
            }
        }

        // 4. 在 16 机器上构建镜像
        stage('在K3s构建Docker镜像') {
            steps {
                sh '''
                    ssh root@${K3S_IP} "cd /opt/spring-petclinic && docker build -t ${DOCKER_IMAGE} ."
                '''
            }
        }

        // 5. 推送镜像
        stage('推送镜像到Harbor') {
            steps {
                withCredentials([usernamePassword(credentialsId: 'HARBOR_CRED', usernameVariable: 'HARBOR_USER', passwordVariable: 'HARBOR_PASS')]) {
                    sh '''
                        ssh root@${K3S_IP} "docker login ${HARBOR_URL} -u ${HARBOR_USER} -p ${HARBOR_PASS}"
                        ssh root@${K3S_IP} "docker push ${DOCKER_IMAGE}"
                    '''
                }
            }
        }

        // 6. 在K3s上部署
        stage('部署到K3s') {
            steps {
                sh '''
                    ssh root@${K3S_IP} "kubectl set image deployment/spring-petclinic spring-petclinic=${DOCKER_IMAGE} -n default"
                    ssh root@${K3S_IP} "kubectl rollout restart deployment/spring-petclinic -n default"
                    sleep 10
                    ssh root@${K3S_IP} "kubectl get pods"
                '''
            }
        }
    }

    post {
        success { echo "✅ 部署成功！" }
        failure { echo "❌ 部署失败！" }
    }
}
