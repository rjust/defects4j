FROM ubuntu:18.04

MAINTAINER ngocpq <phungquangngoc@gmail.com>

#############################################################################
# Setup base image 
#############################################################################
RUN \
  apt-get update -y && \
  apt-get install software-properties-common -y && \
  apt-get update -y && \
  apt-get install -y openjdk-8-jdk \
                ant \
                maven \
                git \
                junit \
                build-essential \
				subversion \
				perl \
				curl \
				unzip \
				cpanminus \
				make \
                && \
  rm -rf /var/lib/apt/lists/*

#############################################################################
# Environment 
#############################################################################

# set java env
ENV JAVA_HOME /usr/lib/jvm/java-8-openjdk-amd64

#############################################################################
# Setup Defects4J
#############################################################################

# -----------Clone defects4j from github--------
WORKDIR /
RUN git clone https://github.com/rjust/defects4j.git defects4j
ENV D4J_HOME /defects4j

# -----------Install defects4j--------
WORKDIR ${D4J_HOME}

RUN cpanm --installdeps .

RUN ./init.sh

ENV PATH="${D4J_HOME}/framework/bin:${PATH}"  
#--------------
