FROM alpine:3.5
# FROM alpine:latest
# Choose older version of Alpine to ensure stability

LABEL Description="Author: cedric.bhihe@gmail.com"

# Docker Build Arguments
ARG SERF_VERSION="0.8.1" 

# RUN mkdir -p /home/ckb/Study/UPC/Subjects/DS_decentralized-computing/Project/Image
# COPY . /home/ckb/Study/UPC/Subjects/DS_decentralized-computing/Project/Image
RUN mkdir -p /opt/app
COPY . /opt/app

RUN \
	apk update && apk add --no-cache \
		unzip \
		wget \
		ca-certificates \
		bash \
		ethtool

# Install Serf 
RUN cd /tmp/ \ 
	&& wget -t 100 --retry-connrefused -O serf_${SERF_VERSION}_linux_amd64.zip \
	https://releases.hashicorp.com/serf/${SERF_VERSION}/serf_${SERF_VERSION}_linux_amd64.zip \
	&& unzip serf_${SERF_VERSION}_linux_amd64.zip \ 
	&& mv serf /usr/local/bin/serf \ 
	&& rm -rf serf_${SERF_VERSION}_linux_amd64.zip 

# Clean up
RUN \
	apk del wget unzip ca-certificates \
	&& rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* 

# Launch serf agent
RUN /bin/sh -c exec serf agent --config-dir=./.config.d

# WORKDIR /home/ckb/Study/UPC/Subjects/DS_decentralized-computing/Project/Image
WORKDIR /opt/app

# Ports for address bind, rpc, clustering
EXPOSE 7946 7373 8443

# Default cmd argument in case the container is instantiated without any cmd
CMD ["agent"]

# Default entry point below, can be ommited in Dockerfile
ENTRYPOINT ["/usr/local/bin/serf"]
