FROM tomcat:10-jdk17-temurin

# Simple demo page (replace later with your real .war file)
RUN echo '<html><body><h1>✅ Hello from Dockerized Tomcat!</h1><p>This is running inside a container. Ready for EKS!</p></body></html>' > /usr/local/tomcat/webapps/ROOT/index.html

EXPOSE 8080
