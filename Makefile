.PHONY: default
default:
	@echo Please choose a target. Available targets:
	@$(MAKE) -pRrq -f $(lastword $(MAKEFILE_LIST)) : 2>/dev/null | awk -v RS= -F: '/^# File/,/^# Finished Make data base/ {if ($$1 !~ "^[#.]") {print $$1}}' | sort | egrep -v -e '^[^[:alnum:]]' -e '^$@$$'

namespace = jenkins-dev
helm_name = dev
jenkins_chart = jenkins/jenkins
JENKINS_VERSION = 2.332.3
prometheus_chart = prometheus-community/prometheus-pushgateway

# kustomize/*.yaml for each jsonnet/*.jsonnet file
jsonnet_files = $(wildcard jsonnet/*.jsonnet)
libsonnet_file = $(wildcard jsonnet/*.libsonnet)
jsonnet_yaml = $(patsubst jsonnet/%.jsonnet, kustomize/%.yaml, $(jsonnet_files))

kustomize_files = $(wildcard kustomize/*.yaml)
kustomize_files += $(jsonnet_yaml)


.PHONY: add-repo
add-repo:
	helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
	helm repo add jenkins https://charts.jenkins.io

.PHONY: install
install: kustomize
	helm install --kubeconfig="./kubeconfig" \
		-n $(namespace) $(helm_name) $(jenkins_chart) -f values.yaml
	helm install --kubeconfig="./kubeconfig" \
		-n $(namespace) pgw $(prometheus_chart) -f pgw.values.yaml

.PHONY: upgrade
upgrade: kustomize
	helm upgrade --kubeconfig="./kubeconfig" \
		-n $(namespace) $(helm_name) $(jenkins_chart) -f values.yaml
	helm upgrade --kubeconfig="./kubeconfig" \
		-n $(namespace) pgw $(prometheus_chart) -f pgw.values.yaml

.PHONY: rollback
rollback: kustomize
	helm rollback \
		-n $(namespace) $(helm_name)
	helm rollback \
		-n $(namespace) pgw

.PHONY: uninstall
uninstall:
	helm uninstall --kubeconfig="./kubeconfig" -n $(namespace) $(helm_name)
	kubectl --kubeconfig="./kubeconfig" delete -k kustomize

.PHONY: kustomize
kustomize: $(kustomize_files)
	kubectl --kubeconfig="./kubeconfig" apply -k kustomize

.PHONY: dry-run
dry-run: $(kustomize_files)
	kubectl --kubeconfig="./kubeconfig" apply --dry-run=server -k kustomize
	helm upgrade --dry-run --kubeconfig="./kubeconfig" \
		-n $(namespace) $(helm_name) $(jenkins_chart) -f values.yaml
	helm upgrade --dry-run --kubeconfig="./kubeconfig" \
		-n $(namespace) pgw $(prometheus_chart) -f pgw.values.yaml


kustomize/%.yaml: jsonnet/%.jsonnet $(libsonnet_file)
	jsonnetfmt -i $^
	jsonnet -J ../../../src/jsonnet/vendor -S $< -o $@


.PHONY: build-jenkins-dev
build-jenkins-dev: Dockerfile
	docker build --no-cache --build-arg JENKINS_VERSION=$(JENKINS_VERSION) -t nickhalden007/jenkins:$(JENKINS_VERSION) -t nickhalden007/jenkins:lts-dev .
	docker push nickhalden007/jenkins:lts-dev

