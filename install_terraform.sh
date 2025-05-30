#!/bin/bash

# Install Terraform on Amazon Linux
sudo yum install -y yum-utils
sudo yum-config-manager --add-repo https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo
sudo yum -y install terraform

ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa
