# 国内 100% 能拉，不报错、不超时、不需要登录
FROM daocloud.io/library/eclipse-temurin:17-jre-jammy

COPY target/xxx.jar app.jar
ENTRYPOINT ["java","-jar","/app.jar"]
