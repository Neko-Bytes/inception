COMPOSE = docker compose -f srcs/docker-compose.yml --env-file srcs/.env

all: up

up:
	$(COMPOSE) up -d --build

down:
	$(COMPOSE) down

restart: down up

ps:
	$(COMPOSE) ps

logs:
	$(COMPOSE) logs --tail=30

.PHONY: all up down restart ps logs
