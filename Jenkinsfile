pipeline {
  agent {
    docker {
      image 'hdxt25/maven-docker-agent:v1'
      args '--user root -v /var/run/docker.sock:/var/run/docker.sock -v /Users/himanshu/.jenkins/tools:/tools'  // mount Docker socket to access the host's Docker daemon
    }
  }
  environment {
        SONAR_URL = "http://3.134.76.152:9000"
        DOCKER_IMAGE = "hdxt25/springboot-app3"
        NVD_API_KEY = credentials('nvd-api-key')
  }
  stages {
    stage('Check and Clean Workspace') {
      steps {
        sh '''
          echo "=== Checking workspace status ==="
          whoami
          id
          ls -ld $WORKSPACE || echo "Workspace empty or inaccessible"
        '''
      }
    }
    stage('Checkout Code') {
      steps {
          git url: "https://github.com/hdxt25/springboot-app3.git", branch: "main", credentialsId: "github-cred" 
      }
    }
    stage('Update Deployment File demo') {
      environment {
            GIT_REPO_NAME = "springboot-app3"
            GIT_USER_NAME = "hdxt25"
      }
      steps {
        withCredentials([string(credentialsId: 'github-cred', variable: 'GITHUB_TOKEN')]) {
              sh '''
                    

                    # Make sure we have latest code
                    
                    git config user.email "hdxt25@gmail.com"
                    git config user.name "himanshu"
                    git config --global --add safe.directory $WORKSPACE
                    BUILD_NUMBER=${BUILD_NUMBER}
                    sed "s|hdxt25/web-app:.*|hdxt25/web-app:${BUILD_NUMBER}|g" spring-boot-app-manifests/deployment.yml > spring-boot-app-manifests/deployment.yml.tmp
                    mv spring-boot-app-manifests/deployment.yml.tmp spring-boot-app-manifests/deployment.yml

                    git add .
                    git commit -m "Update deployment image to version ${BUILD_NUMBER}" || echo "No changes to commit"
                    git push https://${GITHUB_TOKEN}@github.com/${GIT_USER_NAME}/${GIT_REPO_NAME} HEAD:main
              '''
          
        }
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
        sh '''
        echo "=== Running OWASP Dependency Check ==="
        chmod +x /tools/org.jenkinsci.plugins.DependencyCheck.tools.DependencyCheckInstallation/OWASP/bin/dependency-check.sh
        /tools/org.jenkinsci.plugins.DependencyCheck.tools.DependencyCheckInstallation/OWASP/bin/dependency-check.sh --project "springboot-app3" \
        --scan $WORKSPACE --format "ALL" --out $WORKSPACE/dependency-check-report --nvdApiKey $NVD_API_KEY
        echo "=== Dependency Check completed ==="
        '''
      }
      post {
        always {
          echo "Archiving Dependency-Check reports..."
          archiveArtifacts artifacts: 'dependency-check-report/**', allowEmptyArchive: true
        }
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
                apt-get update
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
            GIT_USER_NAME = "hdxt25"
      }
      steps {
        withCredentials([string(credentialsId: 'github', variable: 'GITHUB_TOKEN')]) {
              sh '''
                
                    git config user.email "hdxt25@gmail.com"
                    git config user.name "himanshu"
                    git config --global --add safe.directory $WORKSPACE
                    GIT_COMMIT=${GIT_COMMIT}
                    sed "s/replaceImageTag/${GIT_COMMIT}/g" spring-boot-app-manifests/deployment.yml > spring-boot-app-manifests/deployment.yml.tmp \
                    && mv spring-boot-app-manifests/deployment.yml.tmp spring-boot-app-manifests/deployment.yml

                    git add .
                    git commit -m "Update deployment image to version ${GIT_COMMIT}"
                    git push https://${GITHUB_TOKEN}@github.com/${GIT_USER_NAME}/${GIT_REPO_NAME} HEAD:main
              '''
          
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
    