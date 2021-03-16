POI_CONTAINER=registryois2716.azurecr.io/poi:latest
TRIPS_CONTAINER=registryois2716.azurecr.io/trips:latest
TRIPVIEWER_CONTAINER=registryois2716.azurecr.io/tripviewer:latest
USER_JAVA_CONTAINER=registryois2716.azurecr.io/user-java:latest
USERPROFILE_CONTAINER=registryois2716.azurecr.io/userprofile:latest

init-network:
	docker network create trip-net

# Database

init-db:
	docker run --name sqlserver \
			   --network trip-net \
			   --env "ACCEPT_EULA=y" \
			   --env "SA_PASSWORD=ThisIsADev123~" \
			   -p 1433:1433 \
			   --rm \
			   --detach \
			   -h sqldev \
			   mcr.microsoft.com/mssql/server:2017-latest
	docker exec -it sqlserver /opt/mssql-tools/bin/sqlcmd \
				-S localhost -U SA -P "ThisIsADev123~" \
				-Q 'CREATE DATABASE mydrivingDB'
	docker run --name dataloader \
			   --network trip-net \
			   --env "SQLFQDN=sqldev" \
			   --env "SQLUSER=SA" \
			   --env "SQLPASS=ThisIsADev123~" \
			   --env "SQLDB=mydrivingDB" \
			   --rm \
			   openhack/data-load:v1

stop-db:
	docker kill sqlserver

# POI
build-poi:
	docker build -t $(POI_CONTAINER) ./src/poi

run-poi:
	docker run --name poi \
			   --network trip-net \
			   -h poi \
			   --rm \
			   -p 8080:8080 \
			   -d \
			   --env "SQL_USER=SA" \
    		   --env "SQL_PASSWORD=ThisIsADev123~" \
    		   --env "SQL_SERVER=sqldev" \
    		   --env "SQL_DBNAME=mydrivingDB" \
			   --env "WEB_PORT=8080" \
			   $(POI_CONTAINER)

push-poi:
	docker push $(POI_CONTAINER)

stop-poi:
	docker kill poi

dev-poi: build-poi run-poi

build-trips:
	docker build -t $(TRIPS_CONTAINER) src/trips

push-trips:
	docker push $(TRIPS_CONTAINER)

build-tripviewer:
	docker build -t $(TRIPVIEWER_CONTAINER) src/tripviewer

push-tripviewer:
	docker push $(TRIPVIEWER_CONTAINER)

build-user-java:
	docker build -t $(USER_JAVA_CONTAINER) src/user-java

push-user-java:
	docker push $(USER_JAVA_CONTAINER)

build-userprofile:
	docker build -t $(USERPROFILE_CONTAINER) src/userprofile

push-userprofile:
	docker push $(USERPROFILE_CONTAINER)

build-all: build-poi build-trips build-tripviewer build-user-java build-userprofile

push-all: push-poi push-trips push-tripviewer push-user-java push-userprofile