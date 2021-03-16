init-db:
	docker run --name sqlserver \
			   --env "ACCEPT_EULA=y" \
			   --env "SA_PASSWORD=ThisIsADev123~" \
			   --rm \
			   --detach \
			   -h sqldev \
			   mcr.microsoft.com/mssql/server:2017-latest
	docker run --network bridge \
			   --env "SQLFQDN=sqldev" \
			   --env "SQLUSER=SA" \
			   --env "SQLPASS=ThisIsADev123~" \
			   --env "SQLDB=mydrivingDB" \
			   --rm \
			   openhack/data-load:v1
stop-db:
	docker kill sqlserver