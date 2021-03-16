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
	docker build -t poi:latest ./src/poi

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
			   poi:latest

stop-poi:
	docker kill poi

dev-poi: build-poi run-poi

stop-db:
	docker kill sqlserver
