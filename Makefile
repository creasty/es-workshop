SHELL := /bin/bash -eu -o pipefail

ROOT_PATH := $(shell dirname $(realpath $(lastword ${MAKEFILE_LIST})))
PATH      := ${ROOT_PATH}/script:${PATH}

DOCKER_IMAGE_NAME := creasty/es-workshop
DOCKER_IMAGE_TAG  := latest
DOCKER_IMAGE      := ${DOCKER_IMAGE_NAME}:${DOCKER_IMAGE_TAG}

ES_CONTAINER_NAME := es

ifeq ($(shell uname), Darwin)
	ES_CONTAINER_FLAGS :=
	ES_BIN_FLAGS       := -D es.network.host=0.0.0.0
else
	ES_CONTAINER_FLAGS := --net host
	ES_BIN_FLAGS       :=
endif


#  Setup
#-----------------------------------------------
.PHONY: deps
deps:
	@setup
	@docker pull "${DOCKER_IMAGE}"


#  Docker
#-----------------------------------------------
.PHONY: start
start: stop
	@echo 'Starting container...'
	@docker run \
		--name ${ES_CONTAINER_NAME} \
		-e 'ES_CLUSTER_NAME=es' \
		-e 'ES_NODE_NAME=node-1' \
		-p 9200:9200 \
		-p 9300:9300 \
		${ES_CONTAINER_FLAGS} \
		-v /usr/share/elasticsearch/data \
		"${DOCKER_IMAGE}" \
		elasticsearch ${ES_BIN_FLAGS}

.PHONY: stop
stop:
	@echo 'Stopping running container...'
	@docker stop ${ES_CONTAINER_NAME} > /dev/null 2>&1 || true
	@echo 'Removing container...'
	@docker rm ${ES_CONTAINER_NAME} > /dev/null 2>&1 || true


#  ES
#-----------------------------------------------
.PHONY: index
index: delete
	@echo 'Creating index...'
	@client PUT / --data-binary '@json/index.json'
	@echo 'Importing documents...'
	@client POST /_bulk --data-binary '@json/bulk.json'

.PHONY: delete
delete:
	@echo 'Deleting index...'
	@client DELETE / > /dev/null 2>&1 || true

.PHONY: run
run:
	@bundle exec ruby main.rb | jq -C . | less -R
