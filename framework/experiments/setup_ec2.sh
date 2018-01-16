#!/bin/bash
# Gregory Gay (greg@greggay.com)
# Initial installation setup for Amazon EC2 instances.
# Must be run in sudo mode.

yum update

# Install Java8

## Latest JDK8 version is JDK8u141 released on 19th July, 2017.

BASE_URL_8=http://download.oracle.com/otn-pub/java/jdk/8u141-b15/336fa29ff2bb4ef291e347e091f7f4a7/jdk-8u141

platform="-linux-x64.rpm"

JDK_VERSION=`echo $BASE_URL_8 | rev | cut -d "/" -f1 | rev`

wget -c --no-check-certificate --no-cookies --header "Cookie: oraclelicense=accept-securebackup-cookie" "${BASE_URL_8}${platform}"

rpm -i ${JDK_VERSION}${platform}

echo "export JAVA_HOME=/usr/java/default" >> /home/ec2-user/.bashrc

# Ensure correct versions of Java are used
/usr/sbin/alternatives --config java
/usr/sbin/alternatives --config javac

# Install ant
wget http://archive.apache.org/dist/ant/binaries/apache-ant-1.9.0-bin.tar.gz
tar xzf apache-ant-1.9.0-bin.tar.gz
mv apache-ant-1.9.0 /usr/local/apache-ant
echo 'export ANT_HOME=/usr/local/apache-ant' >> /home/ec2-user/.bashrc
echo 'export PATH=$PATH:/usr/local/apache-ant/bin' >> /home/ec2-user/.bashrc

# Install other dependencies
yum install screen
yum install git
yum install svn
yum install patch
yum install gcc
yum install cpan
cpan DBI
cpan DBD:CSV

# Install Maven
sudo wget http://repos.fedorapeople.org/repos/dchen/apache-maven/epel-apache-maven.repo -O /etc/yum.repos.d/epel-apache-maven.repo
sudo sed -i s/\$releasever/6/g /etc/yum.repos.d/epel-apache-maven.repo
sudo yum install -y apache-maven
mvn --version

# Set up SSH for file uploads
ssh-keygen -t rsa
cat ~/.ssh/id_rsa.pub | ssh bstech@blankslatetech.com "mkdir -p ~/.ssh && cat >>  ~/.ssh/authorized_keys"
