# docker compose commands: https://docs.docker.com/reference/cli/docker/compose/

COMPOSE = docker compose -f srcs/docker-compose.yml
DATA = /home/kmummadi/data

# create the folders for the volumes, then build and start everything
all:
	mkdir -p $(DATA)/mariadb $(DATA)/wordpress
	$(COMPOSE) up -d --build

down:
	$(COMPOSE) down

# stop and remove the containers and images (website data is kept)
clean:
	$(COMPOSE) down --rmi all

# also remove the volumes and the data on disk (sudo: the files belong to the containers' users)
fclean: clean
	$(COMPOSE) down -v
	sudo rm -rf $(DATA)

re: fclean all

.PHONY: all down clean fclean re
