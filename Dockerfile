# 阿里云官方 JDK17 轻量镜像（Docker 打包 + K3s 运行都完美支持）
FROM registry.aliyuncs.com/library/openjdk:17-jre-slim

# 复制你的 jar 包
COPY target/xxx.jar app.jar

# 启动
ENTRYPOINT ["java","-jar","/app.jar"]
