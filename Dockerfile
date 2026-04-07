# 国内最快、不需要登录、K3s/Docker都兼容
FROM eclipse-temurin:17-jre-jammy

COPY target/xxx.jar app.jar
ENTRYPOINT ["java","-jar","/app.jar"]

# 复制你的 jar 包
COPY target/xxx.jar app.jar

# 启动
ENTRYPOINT ["java","-jar","/app.jar"]
