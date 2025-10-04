# You can change this base image to anything else
# But make sure to use the correct version of Java
# FROM maven:3.8.3-openjdk-11
FROM gcr.io/distroless/java17-debian12

# Simply the artifact path
ARG artifact=target/*.jar

WORKDIR /opt/app

COPY ${artifact} app.jar

CMD ["app.jar"]