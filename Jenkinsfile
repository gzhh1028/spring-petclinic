pipeline {
    agent any
    
    environment {
        // 1. Harbor 配置
        HARBOR_URL = '172.21.196.15'  // 你的 Harbor IP
        HARBOR_PROJECT = 'library'
        
        // 2. 应用配置
        APP_NAME = 'springboot-demo'
        APP_VERSION = "${env.BUILD_NUMBER}"
        DOCKER_IMAGE = "${HARBOR_URL}/${HARBOR_PROJECT}/${APP_NAME}:${APP_VERSION}"
        
        // 3. K3s 配置
        K8S_NAMESPACE = 'default'
        
        // 4. SonarQube 配置
        SONARQUBE_URL = '172.21.196.15:9000'  // 修改这里！添加端口
        
        // 5. 凭证 ID（根据你在 Jenkins 的实际配置）
        HARBOR_CREDS_ID = 'HARBOR_CRED'
        SONAR_TOKEN_ID = 'SONAR_CRED'
        KUBECONFIG_ID = 'k3s-kubeconfig'
    }
    
    options {
        buildDiscarder(logRotator(numToKeepStr: '10'))
        timeout(time: 30, unit: 'MINUTES')
    }
    
    stages {
        // 阶段 1: 代码检出
        stage('检出代码') {
            steps {
                checkout scm
                script {
                    // 获取 Git 提交信息
                    env.GIT_COMMIT_SHORT = sh(
                        script: 'git rev-parse --short HEAD',
                        returnStdout: true
                    ).trim()
                    echo "构建版本: ${env.APP_VERSION}"
                    echo "Git提交: ${env.GIT_COMMIT_SHORT}"
                }
            }
        }
        
        // 阶段 2: SonarQube 代码质量扫描
        stage('代码质量扫描') {
            steps {
                script {
                    withCredentials([string(credentialsId: env.SONAR_TOKEN_ID, variable: 'SONAR_TOKEN')]) {
                        sh """
                            mvn clean compile
                            mvn sonar:sonar \
                                -Dsonar.projectKey=${env.APP_NAME} \
                                -Dsonar.projectName=${env.APP_NAME} \
                                -Dsonar.host.url=${env.SONARQUBE_URL} \  # 使用变量
                                -Dsonar.login=${SONAR_TOKEN} \
                                -Dsonar.branch.name=${env.BRANCH_NAME} \
                                -Dsonar.sources=src/main/java \
                                -Dsonar.java.binaries=target/classes
                        """
                    }
                }
            }
        }
        
        // 阶段 3: 等待质量门禁
        stage('等待质量门禁') {
            steps {
                timeout(time: 5, unit: 'MINUTES') {
                    script {
                        def qg = waitForQualityGate()
                        if (qg.status != 'OK') {
                            error "❌ 代码质量门禁未通过: ${qg.status}"
                        }
                        echo "✅ 代码质量门禁通过"
                    }
                }
            }
        }
        
        // 阶段 4: 构建和单元测试
        stage('构建和测试') {
            steps {
                sh '''
                    echo "=== 开始构建和测试 ==="
                    mvn clean package
                    
                    # 显示测试结果
                    echo "=== 单元测试结果 ==="
                    if [ -f target/surefire-reports/*.xml ]; then
                        cat target/surefire-reports/*.xml | grep -E "<testcase|<failure" | head -20
                    fi
                '''
                
                // 存档测试报告
                junit 'target/surefire-reports/*.xml'
                archiveArtifacts artifacts: 'target/*.jar'
            }
        }
        
        // 阶段 5: 构建 Docker 镜像
        stage('构建 Docker 镜像') {
            steps {
                script {
                    echo "=== 构建 Docker 镜像 ==="
                    echo "镜像名称: ${env.DOCKER_IMAGE}"
                    
                    sh """
                        # 查看 Dockerfile
                        cat Dockerfile || echo "没有 Dockerfile，使用默认配置"
                        
                        # 创建简单的 Dockerfile（如果不存在）
                        if [ ! -f Dockerfile ]; then
                            cat > Dockerfile << 'EOF'
FROM openjdk:11-jre-slim
WORKDIR /app
COPY target/*.jar app.jar
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "app.jar"]
EOF
                        fi
                        
                        # 构建镜像
                        docker build -t ${env.DOCKER_IMAGE} .
                        
                        # 列出镜像
                        docker images | grep ${APP_NAME}
                    """
                }
            }
        }
        
        // 阶段 6: 推送到 Harbor
        stage('推送到 Harbor') {
            steps {
                script {
                    withCredentials([
                        usernamePassword(
                            credentialsId: env.HARBOR_CREDS_ID,
                            usernameVariable: 'HARBOR_USER',
                            passwordVariable: 'HARBOR_PASSWORD'
                        )
                    ]) {
                        echo "=== 登录 Harbor ==="
                        echo "Harbor地址: ${env.HARBOR_URL}"
                        echo "用户名: ${HARBOR_USER}"
                        
                        sh """
                            # 登录 Harbor
                            docker login ${env.HARBOR_URL} \
                                -u ${HARBOR_USER} \
                                -p ${HARBOR_PASSWORD} || {
                                    echo "❌ Harbor 登录失败"
                                    exit 1
                                }
                            
                            # 推送镜像
                            docker push ${env.DOCKER_IMAGE} && echo "✅ 镜像推送成功"
                            
                            # 也打上 latest 标签（如果是主分支）
                            if [ "${env.BRANCH_NAME}" = "main" ] || [ "${env.BRANCH_NAME}" = "master" ]; then
                                docker tag ${env.DOCKER_IMAGE} ${env.HARBOR_URL}/${env.HARBOR_PROJECT}/${env.APP_NAME}:latest
                                docker push ${env.HARBOR_URL}/${env.HARBOR_PROJECT}/${env.APP_NAME}:latest
                                echo "✅ latest 标签已推送"
                            fi
                        """
                    }
                }
            }
        }
        
        // 阶段 7: 部署到 K3s
        stage('部署到 K3s') {
            steps {
                script {
                    withCredentials([
                        file(
                            credentialsId: env.KUBECONFIG_ID,
                            variable: 'KUBECONFIG_FILE'
                        ),
                        usernamePassword(
                            credentialsId: env.HARBOR_CREDS_ID,
                            usernameVariable: 'HARBOR_USER',
                            passwordVariable: 'HARBOR_PASSWORD'
                        )
                    ]) {
                        echo "=== 部署到 K3s ==="
                        
                        sh """
                            # 设置 kubeconfig
                            mkdir -p ~/.kube
                            cp ${KUBECONFIG_FILE} ~/.kube/config
                            
                            # 检查集群状态
                            echo "=== 检查 K3s 集群 ==="
                            kubectl cluster-info
                            kubectl get nodes
                            kubectl get pods -A
                            
                            # 创建或更新命名空间
                            kubectl create namespace ${env.K8S_NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -
                            
                            # 创建 Harbor 镜像拉取凭证
                            kubectl create secret docker-registry harbor-registry \
                                --docker-server=${env.HARBOR_URL} \
                                --docker-username=${HARBOR_USER} \
                                --docker-password=${HARBOR_PASSWORD} \
                                --namespace=${env.K8S_NAMESPACE} \
                                --dry-run=client -o yaml | kubectl apply -f -
                        """
                        
                        // 检查是否已有 K8s 配置文件
                        def k8sDirExists = fileExists('k8s')
                        if (k8sDirExists) {
                            echo "✅ 使用现有的 k8s 配置文件"
                            sh """
                                # 使用现有的 k8s 配置
                                if [ -f k8s/deployment.yaml ]; then
                                    # 替换镜像标签
                                    sed -i "s|IMAGE_PLACEHOLDER|${env.DOCKER_IMAGE}|g" k8s/deployment.yaml
                                    kubectl apply -f k8s/ -n ${env.K8S_NAMESPACE}
                                else
                                    echo "没有找到 deployment.yaml，创建默认配置"
                                    createDefaultK8sManifests()
                                fi
                            """
                        } else {
                            echo "⚠️ 没有 k8s 目录，创建默认部署配置"
                            createDefaultK8sManifests()
                        }
                        
                        // 等待部署完成
                        sh """
                            echo "=== 等待部署完成 ==="
                            kubectl rollout status deployment/${env.APP_NAME} \
                                -n ${env.K8S_NAMESPACE} \
                                --timeout=300s
                            
                            echo "=== 部署状态 ==="
                            kubectl get all -n ${env.K8S_NAMESPACE}
                        """
                    }
                }
            }
        }
        
        // 阶段 8: 验证部署
        stage('验证部署') {
            steps {
                script {
                    echo "=== 验证部署 ==="
                    
                    sh """
                        # 获取服务信息
                        kubectl get svc -n ${env.K8S_NAMESPACE}
                        
                        # 获取 Pod 日志
                        kubectl logs deployment/${env.APP_NAME} \
                            -n ${env.K8S_NAMESPACE} \
                            --tail=20
                        
                        # 尝试访问应用
                        POD_NAME=\$(kubectl get pods -n ${env.K8S_NAMESPACE} -l app=${env.APP_NAME} -o jsonpath='{.items[0].metadata.name}')
                        if [ ! -z "\$POD_NAME" ]; then
                            echo "=== 执行健康检查 ==="
                            kubectl exec \$POD_NAME -n ${env.K8S_NAMESPACE} -- curl -s http://localhost:8080/actuator/health || true
                            kubectl exec \$POD_NAME -n ${env.K8S_NAMESPACE} -- curl -s http://localhost:8080/ || true
                        fi
                    """
                }
            }
        }
    }
    
    post {
        always {
            // 清理
            sh '''
                echo "=== 清理工作空间 ==="
                docker image prune -f || true
                rm -f ~/.docker/config.json ~/.kube/config || true
            '''
            
            // 记录构建信息
            script {
                def duration = currentBuild.durationString
                echo "构建耗时: ${duration}"
                
                // 生成构建报告
                def report = """
                ===== 构建报告 =====
                项目: ${env.APP_NAME}
                版本: ${env.APP_VERSION}
                镜像: ${env.DOCKER_IMAGE}
                状态: ${currentBuild.result ?: 'SUCCESS'}
                耗时: ${duration}
                提交: ${env.GIT_COMMIT_SHORT}
                分支: ${env.BRANCH_NAME}
                ===================
                """
                
                echo report
            }
        }
        
        success {
            echo "✅ ✅ ✅ 构建部署成功！"
            sh '''
                # 显示访问信息
                echo "应用部署完成！"
                echo "查看应用: kubectl get pods -n ${K8S_NAMESPACE}"
                echo "查看日志: kubectl logs deployment/${APP_NAME} -n ${K8S_NAMESPACE} -f"
            '''
        }
        
        failure {
            echo "❌ ❌ ❌ 构建部署失败！"
            
            // 尝试获取失败原因
            sh '''
                echo "=== 故障诊断 ==="
                kubectl describe deployment/${APP_NAME} -n ${K8S_NAMESPACE} || true
                kubectl get events -n ${K8S_NAMESPACE} --sort-by='.lastTimestamp' || true
            '''
        }
    }
}

// 辅助函数：创建默认的 K8s 配置文件
def createDefaultK8sManifests() {
    sh """
        # 创建 k8s 目录
        mkdir -p k8s
        
        # 创建 deployment.yaml
        cat > k8s/deployment.yaml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ${env.APP_NAME}
  namespace: ${env.K8S_NAMESPACE}
  labels:
    app: ${env.APP_NAME}
    version: ${env.APP_VERSION}
spec:
  replicas: 2
  selector:
    matchLabels:
      app: ${env.APP_NAME}
  template:
    metadata:
      labels:
        app: ${env.APP_NAME}
        version: ${env.APP_VERSION}
    spec:
      containers:
      - name: ${env.APP_NAME}
        image: ${env.DOCKER_IMAGE}
        imagePullPolicy: Always
        ports:
        - containerPort: 8080
        env:
        - name: JAVA_OPTS
          value: "-Xmx512m -Xms256m"
        - name: APP_VERSION
          value: "${env.APP_VERSION}"
        resources:
          requests:
            memory: "256Mi"
            cpu: "100m"
          limits:
            memory: "512Mi"
            cpu: "500m"
        livenessProbe:
          httpGet:
            path: /actuator/health
            port: 8080
          initialDelaySeconds: 60
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /actuator/health
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 5
      imagePullSecrets:
      - name: harbor-registry
EOF
        
        # 创建 service.yaml
        cat > k8s/service.yaml << 'EOF'
apiVersion: v1
kind: Service
metadata:
  name: ${env.APP_NAME}
  namespace: ${env.K8S_NAMESPACE}
spec:
  selector:
    app: ${env.APP_NAME}
  ports:
  - port: 80
    targetPort: 8080
    name: http
  type: ClusterIP
EOF
        
        # 应用配置
        kubectl apply -f k8s/ -n ${env.K8S_NAMESPACE}
    """
}
