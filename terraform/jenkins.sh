#!/bin/bash
# ============================================
# Jenkins Installation Script for Amazon Linux 2
# ============================================

# Update the system
yum update -y

# Install Java 11 (required for Jenkins)
amazon-linux-extras install java-openjdk11 -y

# Add Jenkins repo
wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io.key

# Install Jenkins
yum install -y jenkins

# Enable and start Jenkins service
systemctl enable jenkins
systemctl start jenkins

# Allow firewall (if running) for port 8080
if systemctl is-active firewalld &>/dev/null; then
    firewall-cmd --permanent --zone=public --add-port=8080/tcp
    firewall-cmd --reload
fi

# Print initial admin password to console for Terraform logs / CloudInit
echo "===================================================="
echo "Jenkins Installed! Access it at http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):8080"
echo "Initial Admin Password:"
cat /var/lib/jenkins/secrets/initialAdminPassword
echo "===================================================="
