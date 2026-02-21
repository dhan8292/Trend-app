output "jenkins_url" {
  value = "http://${aws_instance.jenkins.public_ip}:8080"
}

output "eks_cluster_name" {
  value = aws_eks_cluster.eks.name
}
