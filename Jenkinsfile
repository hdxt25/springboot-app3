pipeline {
  agent {
    docker {
      image "hdxt25/maven-docker-agent:v1" 
      args "--user root -v /var/run/docker.sock:/var/run/docker.sock -v ${env.WORKSPACE}:/workspace --workdir /workspace" // mount Docker socket to access the host's Docker daemon
    }
  }
  environment {
        SONAR_URL = "http://3.134.76.152:9000"
        DOCKER_IMAGE = "hdxt25/springboot-app3"
  }
  stages {
    stage('Git: Code Checkout') {
      steps {
         git url: "https://github.com/hdxt25/springboot-app3.git", branch: "main", credentialsId: "github-cred"
      }    
    }
    stage('check') {
      steps {
        sh '''
          echo "Current directory: $(pwd)"
          echo "Contents of /workspace:"
          ls -al /workspace
        '''
      }
    }
    stage("Trivy: Filesystem scan") {
      steps {
        sh ' trivy fs --debug --skip-dirs target,.git /workspace '        
      } 
    }
    stage('Build and Test') {
      steps {
        sh 'mvn clean package'
      }
    }
    stage('Dependency-Check') {
      steps {
        sh 'mvn org.owasp:dependency-check-maven:check'
      }
      post {
        always {
          archiveArtifacts artifacts: 'target/dependency-check-report.html', fingerprint: true
        }
      }
    }
  /*  stage('Static Code Analysis') {
      steps {
        withCredentials([string(credentialsId: 'sonarqube', variable: 'SONAR_AUTH_TOKEN')]) {
          sh 'mvn sonar:sonar -Dsonar.login=$SONAR_AUTH_TOKEN -Dsonar.host.url=${SONAR_URL}'
        }
      }
    }*/
    stage('Docker Build (Local Only)') {
      steps {
        sh '''
            docker buildx create --name multiarch --platform linux/amd64,linux/arm64 --driver docker-container --bootstrap --use
            # Build single arch and load locally for scanning
            docker buildx build --platform linux/amd64 -t $DOCKER_IMAGE:$GIT_COMMIT --load .       
            '''
      }
    }
    stage('Run Trivy vulnerability scanner') {
      steps {
        sh '''         
            # Run Trivy scan on the staging Docker image
            trivy image --exit-code 1 --severity HIGH,CRITICAL $DOCKER_IMAGE:$GIT_COMMIT           
            '''
      }
    }
    stage('build & push final docker image') {
      steps {
        withCredentials([usernamePassword(credentialsId:'docker-cred',
                                                        usernameVariable: DOCKER_USER,
                                         passwordVariable: DOCKER_PASS)]) {
            sh '''
                            
                echo "$DOCKER_PASS" | docker login -u "$DOCKER_USER" --password-stdin
                # docker buildx create --name multiarch --platform linux/amd64,linux/arm64 --driver docker-container --bootstrap --use
                # Build and push multi-arch image
                docker buildx build --platform linux/amd64,linux/arm64,linux/arm/v7 -t $DOCKER_IMAGE:$GIT_COMMIT --push .            
                docker logout              
                '''
            }                                          
        }
    }
    stage('Update Deployment File') {
      environment {
        GIT_REPO_NAME = "springboot-app3"           
      }
      steps {    
        script {
          withCredentials([usernamePassword(credentialsId: 'github-cred', 
                                          usernameVariable: 'GIT_USER', 
                                          passwordVariable: 'GIT_PASS')]) {
                sh '''
                    # Configure Git identity
                    git config user.email "hdxt25@gmail.com"
                    git config user.name "himanshu"
                    git config --global --add safe.directory $WORKSPACE

                    # Update deployment manifest with Jenkins BUILD_NUMBER
                    sed -i "s/replaceImageTag/$GIT_COMMIT/g" spring-boot-app-manifests/deployment.yml

                    # Stage and commit changes
                    git add spring-boot-app-manifests/deployment.yml
                    git commit -m "Update deployment image to version ${GIT_COMMIT}" || echo "No changes to commit"

                    # Push changes using username/password from Jenkins credentials
                    git push https://$GIT_USER:$GIT_PASS@github.com/$GIT_USER/$GIT_REPO_NAME.git HEAD:main
                '''
          }
        }
      }
    }
  }
}
    