pipeline {
    agent any

    stages {

        stage('Clone Repo') {
            steps {
                git 'https://github.com/dhan8292/Trend-app.git'
            }
        }

        stage('Build Docker Image') {
            steps {
                sh 'docker build -t trend-app .'
            }
        }

        stage('Tag Image') {
            steps {
                sh 'docker tag trend-app dhanu92/trend-app:latest' 
            }
        }

        stage('Push to DockerHub') {
            steps {
                sh 'docker push dhanu92/trend-app:latest' 
            }
        }

        stage('Deploy to Kubernetes') {
            stepsh {'kubectl apply -f k8s/deployment.yml'
                sh 'kubectl apply -f k8s/service.yml'
                sh 'kubectl apply -f service.yml'
            }
        }
    }
}
