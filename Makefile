#!/bin/bash

OS = $(shell uname)
UID = $(shell id -u)
DOCKER_BE = service_name-docker-be
NAMESERVER_IP = $(shell ip address | grep docker0)

ifeq ($(OS),Darwin)
	NAMESERVER_IP = host.docker.internal
else ifeq ($(NAMESERVER_IP),)
	NAMESERVER_IP = $(shell grep nameserver /etc/resolv.conf  | cut -d ' ' -f2)
else
	NAMESERVER_IP = 172.17.0.1 # replace this IP with your "docker0" one (run "ip a" in your terminal to check it)
endif

help: ## Show this help message
	@echo 'usage: make [target]'
	@echo
	@echo 'targets:'
	@egrep '^(.+)\:\ ##\ (.+)' ${MAKEFILE_LIST} | column -t -c 2 -s ':#'

start: ## Start the containers
	docker network create service_name-docker-net || true
	U_ID=${UID} docker-compose up -d

stop: ## Stop the containers
	U_ID=${UID} docker-compose stop

restart: ## Restart the containers
	$(MAKE) stop && $(MAKE) start

build: ## Rebuilds all the containers
	docker network create service_name-docker-net || true
	U_ID=${UID} docker-compose build

prepare: ## Runs backend commands
	$(MAKE) composer-install
	$(MAKE) migrations

# Backend commands
composer-install: ## Installs composer dependencies
	U_ID=${UID} docker exec --user ${UID} ${DOCKER_BE} composer install --no-interaction

migrations: ## Installs composer dependencies
	U_ID=${UID} docker exec --user ${UID} ${DOCKER_BE} bin/console doctrine:migration:migrate -n --allow-no-migration

be-logs: ## Tails the Symfony dev log
	U_ID=${UID} docker exec --user ${UID} ${DOCKER_BE} tail -f var/log/dev.log
# End backend commands

ssh-be: ## bash into the be container
	U_ID=${UID} docker exec -it --user ${UID} ${DOCKER_BE} bash

code-style: ## Runs php-cs to fix code styling following Symfony rules
	U_ID=${UID} docker exec --user ${UID} ${DOCKER_BE} php-cs-fixer fix src --rules=@Symfony

tests: ## Run tests
	U_ID=${UID} docker exec --user ${UID} ${DOCKER_BE} bin/phpunit

generate-ssh-keys: ## Generate ssh keys in the container
	U_ID=${UID} docker exec --user ${UID} ${DOCKER_BE} mkdir -p config/jwt
	U_ID=${UID} docker exec --user ${UID} ${DOCKER_BE} openssl genrsa -passout pass:a6b664029f48d1863f08e9aaa039f554 -out config/jwt/private.pem -aes256 4096
	U_ID=${UID} docker exec --user ${UID} ${DOCKER_BE} openssl rsa -pubout -passin pass:a6b664029f48d1863f08e9aaa039f554 -in config/jwt/private.pem -out config/jwt/public.pem
	U_ID=${UID} docker exec --user ${UID} ${DOCKER_BE} chmod 644 config/jwt/*

.PHONY: migrations tests

