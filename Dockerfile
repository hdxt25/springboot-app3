# You can change this base image to anything else
# But make sure to use the correct version of Java
# FROM maven:3.8.3-openjdk-11
FROM eclipse-temurin:24.0.2_12-jre-alpine-3.22

# Simply the artifact path
ARG artifact=target/*.jar

WORKDIR /opt/app

COPY ${artifact} app.jar

CMD ["java", "-jar", "app.jar"]