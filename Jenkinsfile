pipeline {
  agent {
    docker {
      image "hdxt25/maven-docker-agent:v1" 
      args "--user root -v /var/run/docker.sock:/var/run/docker.sock -v /Users/himanshu/.jenkins/tools:/tools"  // mount Docker socket to access the host's Docker daemon
    }
  }
  environment {
        SONAR_URL = "http://3.134.76.152:9000"
        DOCKER_IMAGE = "hdxt25/springboot-app3"
  }
  stages {
    stage('Check and Clean Workspace') {
      steps {
        // List contents before cleanup
        sh 'ls -la $WORKSPACE || echo "Workspace empty or inaccessible"'
        
        // Clean workspace
        
      }
    }
    stage('Checkout Code') {
      steps {
          git url: "https://github.com/hdxt25/springboot-app3.git", branch: "main", credentialsId: "github-cred"
      }
    }
    stage('Build and Test') {
      steps {
        sh 'mvn clean package'
      }
    }
    stage("Trivy: Filesystem scan") {
      steps {
        sh ' trivy fs --scanners vuln --severity HIGH,CRITICAL --ignore-unfixed ${WORKSPACE} '        
      } 
    }
    stage('SCA - OWASP Dependency Check') {
      steps {
        dependencyCheck additionalArguments: "--scan $WORKSPACE", odcInstallation: 'OWASP'
        dependencyCheckPublisher pattern: '**/dependency-check-report.xml', 
                                  failedTotalHigh: 10,
                                 unstableTotalHigh: 10,
                                 failedTotalCritical: 10,
                                 unstableTotalCritical: 10
     }
    }
   /*
      stage('SAST: SONARQUBE: Static Code Analysis') {
      steps {
        withCredentials([string(credentialsId: 'sonarqube', variable: 'SONAR_AUTH_TOKEN')]) {
          sh 'mvn sonar:sonar -Dsonar.login=$SONAR_AUTH_TOKEN -Dsonar.host.url=${SONAR_URL}'
        }
      }
    } */
    stage('Trivy: Image scan') {
      steps {
        sh '''
            docker build  -t $DOCKER_IMAGE:$GIT_COMMIT .   

            # Run Trivy scan on the just-built image
            trivy image --scanners vuln --severity HIGH,CRITICAL --ignore-unfixed  $DOCKER_IMAGE:$GIT_COMMIT   || true 
            
            '''
      }
    }
    stage('DAST:  OWASP ZAP') {
      steps {
        sh '''
          # Run your app inside Docker container
          docker run -d --name app-under-test -p 8085:8080 $DOCKER_IMAGE:$GIT_COMMIT
          sleep 20

          # Run ZAP scan against container
          mkdir -p "$WORKSPACE/zap_reports"
          docker run --rm -v "$WORKSPACE/zap_reports:/zap/wrk:rw" --network host \
              ghcr.io/zaproxy/zaproxy:2.14.0 zap-baseline.py \
              -t http://localhost:8085 \
              -r zap-baseline-report.html \
              -J zap-baseline-report.json -d || true

          # Stop app container & remove test image
          docker stop app-under-test
          docker rm app-under-test
          docker rmi $DOCKER_IMAGE:$GIT_COMMIT || true
        '''
      }
      post {
        always {
          archiveArtifacts artifacts: 'zap_reports/*.html', fingerprint: true
          archiveArtifacts artifacts: 'zap_reports/*.json', fingerprint: true
        }
      }
    }
    stage('build & push final multiarch docker image') {
      steps {
        withCredentials([usernamePassword(credentialsId:'docker-cred',
                                                        usernameVariable: 'DOCKER_USER',
                                         passwordVariable: 'DOCKER_PASS')]) {
            sh '''
                            
                echo "$DOCKER_PASS" | docker login -u "$DOCKER_USER" --password-stdin
                docker buildx create --name multiarch --platform linux/amd64,linux/arm64 --driver docker-container --bootstrap --use
                # Build and push multi-arch image
                docker buildx build --platform linux/amd64,linux/arm64 -t $DOCKER_IMAGE:$GIT_COMMIT --push .            
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
                    # Ensure permissions
                    chown -R $(id -u):$(id -g) $WORKSPACE
                    chmod -R u+w $WORKSPACE
  
                    # Configure Git identity
                    git config user.email "hdxt25@gmail.com"
                    git config user.name "himanshu"
                    git config --global --add safe.directory $WORKSPACE

                    # Copy the deployment file to container temp directory
                    # cp spring-boot-app-manifests/deployment.yml /tmp/deployment.yml

                    # Replace the image tag inside the temp file
                    # sed -i "s/replaceImageTag/$GIT_COMMIT/g" /tmp/deployment.yml

                    # Move the edited file back to the original location
                    # mv /tmp/deployment.yml spring-boot-app-manifests/deployment.yml
                    # Update deployment manifest with Jenkins BUILD_NUMBER
                      sed -i "s/replaceImageTag/$GIT_COMMIT/g" spring-boot-app-manifests/deployment.yml

                    # Stage and commit changes
                    git add .
                    git commit -m "Update deployment image to version ${GIT_COMMIT}" || echo "No changes to commit"

                    # Push changes using username/password from Jenkins credentials
                    git push https://$GIT_USER:$GIT_PASS@github.com/$GIT_USER/$GIT_REPO_NAME.git HEAD:main
                '''
          }
        }
      }
    }
  }
  post {
    always {
      // No Docker cleanup needed since app isn’t run
      cleanWs()
      echo "Pipeline finished."
    }
  }
}
    