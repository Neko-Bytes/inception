COMPOSE = docker compose -f srcs/docker-compose.yml

all: up

up:
	# Create the host data directory if it does not exist.
	mkdir -p $(HOME)/data/wordpress
	$(COMPOSE) up -d --build

down:
	$(COMPOSE) down

clean:
	$(COMPOSE) down --rmi all --volumes --remove-orphans
	rm -rf $(HOME)/data

fclean: clean

re: fclean all

.PHONY: all up down clean fclean re
