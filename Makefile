init-network:
	docker network create trip-net

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

build-poi:
	docker build -t poi:latest --file dockerfiles/Dockerfile_3 .

stop-db:
	docker kill sqlserver
