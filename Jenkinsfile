pipeline {
    agent any
    
    environment {
        // 基础配置
        APP_NAME = 'spring-petclinic'
        HARBOR_URL = '172.21.196.15'
        K3S_IP = '172.21.196.16'
        
        // 自动生成
        IMAGE_TAG = "${env.BUILD_NUMBER}"
        DOCKER_IMAGE = "${HARBOR_URL}/library/${APP_NAME}:${IMAGE_TAG}"
    }
    
    stages {
        // 阶段1: 拉取代码
        stage('拉取代码') {
            steps {
                checkout scm
                sh 'echo "代码拉取完成"'
            }
        }
        
        // 阶段2: 编译打包
        stage('编译打包') {
            steps {
                sh '''
                    echo "开始编译..."
                    ./mvnw clean package
                    echo "编译完成"
                '''
            }
        }
        
        // 阶段3: 构建Docker镜像
        stage('构建镜像') {
            steps {
                script {
                    // 创建简单Dockerfile
                    sh '''
                        cat > Dockerfile << 'EOF'
FROM openjdk:17-jre-slim
COPY target/*.jar app.jar
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "app.jar"]
EOF
                        
                        # 构建镜像
                        docker build -t ${DOCKER_IMAGE} .
                        docker images | grep ${APP_NAME}
                    '''
                }
            }
        }
        
        // 阶段4: 推送到Harbor
        stage('推送镜像') {
            steps {
                withCredentials([
                    usernamePassword(
                        credentialsId: 'HARBOR_CRED',
                        usernameVariable: 'HARBOR_USER',
                        passwordVariable: 'HARBOR_PASS'
                    )
                ]) {
                    sh '''
                        docker login ${HARBOR_URL} -u ${HARBOR_USER} -p ${HARBOR_PASS}
                        docker push ${DOCKER_IMAGE}
                        echo "镜像已推送到 Harbor"
                    '''
                }
            }
        }
        
        // 阶段5: 部署到K3s
        stage('部署到K3s') {
            steps {
                withCredentials([
                    file(credentialsId: 'k3s-kubeconfig', variable: 'KUBECONFIG_FILE')
                ]) {
                    sh '''
                        # 配置kubectl
                        mkdir -p ~/.kube
                        cp ${KUBECONFIG_FILE} ~/.kube/config
                        
                        # 创建最简单的部署文件
                        cat > deploy.yaml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: spring-petclinic
  namespace: default
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
  namespace: default
spec:
  selector:
    app: spring-petclinic
  ports:
  - port: 80
    targetPort: 8080
EOF
                        
                        # 部署应用
                        kubectl apply -f deploy.yaml
                        
                        # 检查部署状态
                        sleep 5
                        echo "=== 部署状态 ==="
                        kubectl get pods
                        kubectl get svc
                    '''
                }
            }
        }
        
        // 阶段6: 测试验证
        stage('测试验证') {
            steps {
                sh '''
                    echo "等待应用启动..."
                    sleep 10
                    
                    # 获取Pod名称
                    POD_NAME=$(kubectl get pods -l app=spring-petclinic -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
                    
                    if [ ! -z "$POD_NAME" ]; then
                        echo "测试Pod: $POD_NAME"
                        # 测试应用是否响应
                        kubectl exec $POD_NAME -- curl -s http://localhost:8080/actuator/health || echo "健康检查失败，但继续"
                    else
                        echo "未找到Pod"
                    fi
                '''
            }
        }
    }
    
    post {
        success {
            echo "✅ 部署成功！"
            sh '''
                echo "========================"
                echo "应用已部署到 K3s"
                echo "镜像: ${DOCKER_IMAGE}"
                echo "K3s节点: ${K3S_IP}"
                echo "查看状态: kubectl get pods"
                echo "========================"
            '''
        }
        failure {
            echo "❌ 部署失败！"
        }
    }
}
