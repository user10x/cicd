ARG JENKINS_VERSION=lts-dev
FROM jenkins/jenkins:${JENKINS_VERSION}
COPY plugins.txt /usr/share/jenkins/ref/plugins.txt
ENV CASC_JENKINS_CONFIG "/data/jenkins/casc_conf"
RUN jenkins-plugin-cli -f /usr/share/jenkins/ref/plugins.txt

