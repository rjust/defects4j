#!/bin/bash
# Gregory Gay (greg@greggay.com)
# Initial installation setup for local Ubuntu VM instances.
# Must be run in sudo mode.

# Install Java8

## Latest JDK8 version is JDK8u141 released on 19th July, 2017.

add-apt-repository ppa:webupd8team/java
apt-get update
apt-get install oracle-java8-installer

echo 'export JAVA_HOME=/usr/lib/jvm/java-8-oracle/' >> /home/greg/.bashrc

# Ensure correct versions of Java are used
/usr/sbin/alternatives --config java
/usr/sbin/alternatives --config javac

# Install ant
apt-get install ant
wget http://archive.apache.org/dist/ant/binaries/apache-ant-1.9.0-bin.tar.gz
tar xzf apache-ant-1.9.0-bin.tar.gz
mv apache-ant-1.9.0 /usr/local/apache-ant
echo 'export ANT_HOME=/usr/local/apache-ant' >> /home/greg/.bashrc
echo 'export PATH=$PATH:/usr/local/apache-ant/bin' >> /home/greg/.bashrc

# Install other dependencies
apt-get install maven

echo 'export M2_HOME=/usr/share/maven' >> /home/greg/.bashrc

apt-get install make
apt-get install screen
apt-get install unzip
apt-get install git
#apt-get install svn
apt-get install patch
apt-get install gcc
#apt-get install cpan
cpan DBI
cpan DBD:CSV

# Set up SSH for file uploads
ssh-keygen -t rsa
cat ~/.ssh/id_rsa.pub | ssh bstech@blankslatetech.com "mkdir -p ~/.ssh && cat >>  ~/.ssh/authorized_keys"
