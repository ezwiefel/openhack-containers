POI_CONTAINER=registryois2716.azurecr.io/poi:latest
TRIPS_CONTAINER=registryois2716.azurecr.io/trips:latest
TRIPVIEWER_CONTAINER=registryois2716.azurecr.io/tripviewer:latest
USER_JAVA_CONTAINER=registryois2716.azurecr.io/user-java:latest
USERPROFILE_CONTAINER=registryois2716.azurecr.io/userprofile:latest
SQL_PASSWORD=ThisIsADev123~
NETWORK_NAME=trip-net
AKS_CLUSTER=aks-stage-2
RESOURCE_GROUP_NAME=teamResources
VNET_ID=/subscriptions/3f5ea060-40e5-4996-b0b5-c027700f0fc9/resourceGroups/teamResources/providers/Microsoft.Network/virtualNetworks/vnet
SUBNET_ID=/subscriptions/3f5ea060-40e5-4996-b0b5-c027700f0fc9/resourceGroups/teamResources/providers/Microsoft.Network/virtualNetworks/vnet/subnets/aks-subnet
SP_ID=c0fd770d-2057-4691-813d-08248b75c464
SP_PASSWORD=TpyDjJ4ItyPyQKlq658~463X2zQzdnuynC

init-network:
	docker network create $(NETWORK_NAME)

# Database
init-db:
	docker run --name sqlserver \
			   --network $(NETWORK_NAME) \
			   --env "ACCEPT_EULA=y" \
			   --env "SA_PASSWORD=$(SQL_PASSWORD)" \
			   -p 1433:1433 \
			   --rm \
			   --detach \
			   -h sqldev \
			   mcr.microsoft.com/mssql/server:2017-latest
	docker exec -it sqlserver /opt/mssql-tools/bin/sqlcmd \
				-S localhost -U SA -P "$(SQL_PASSWORD)" \
				-Q 'CREATE DATABASE mydrivingDB'
	docker run --name dataloader \
			   --network $(NETWORK_NAME) \
			   --env "SQLFQDN=sqldev" \
			   --env "SQLUSER=SA" \
			   --env "SQLPASS=$(SQL_PASSWORD)" \
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
			   --network $(NETWORK_NAME) \
			   -h poi \
			   --rm \
			   -p 8080:8080 \
			   -d \
			   --env "SQL_USER=SA" \
    		   --env "SQL_PASSWORD=$(SQL_PASSWORD)" \
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

deploy-namespace:
	kubectl apply -f manifests/namespaces/namespaces.yaml

deploy-all:
	kubectl apply -f manifests/api/trip-api.yaml 
	kubectl apply -f manifests/api/poi-api.yaml 
	kubectl apply -f manifests/api/user-java-api.yaml 
	kubectl apply -f manifests/api/user-profile-api.yaml
	kubectl apply -f manifests/front-end/trip-viewer.yaml

admin:
	az aks get-credentials --name $(AKS_CLUSTER) -g teamResources --overwrite-existing --admin

reg:
	az aks get-credentials --name $(AKS_CLUSTER) -g teamResources --overwrite-existing

apply-roles:
	kubectl apply -f manifests/roles/api-dev.yaml
	kubectl apply -f manifests/roles/web-dev.yaml

can-i:
	kubectl auth can-i list pods --as=hacker1dv7@OTAPRD253ops.onmicrosoft.com -n api

network:
	az network watcher show-next-hop \
	--dest-ip 10.2.0.4 \
	--resource-group teamResources \
	--source-ip 10.2.2.52 \
	--vm internal-vm \
	--nic internal-vmVMNic

helm-csi:
	helm repo add csi-secrets-store-provider-azure https://raw.githubusercontent.com/Azure/secrets-store-csi-driver-provider-azure/master/charts/
	helm install csi csi-secrets-store-provider-azure/csi-secrets-store-provider-azure -n csi

helm-nginx:
	helm install nginx-ingress ingress-nginx/ingress-nginx \
    --namespace front-end \
    --set controller.replicaCount=2 \
    --set controller.nodeSelector."beta\.kubernetes\.io/os"=linux \
    --set defaultBackend.nodeSelector."beta\.kubernetes\.io/os"=linux \
    --set controller.admissionWebhooks.patch.nodeSelector."beta\.kubernetes\.io/os"=linux

shell:
	kubectl run --rm -it --image=mcr.microsoft.com/aks/fundamental/base-ubuntu:v0.0.11 network-policy --namespace development


# helm install nginx-ingress ingress-nginx/ingress-nginx \
#     --namespace front-end \
#     --set controller.replicaCount=2 \
#     --set controller.nodeSelector."beta\.kubernetes\.io/os"=linux \
#     --set defaultBackend.nodeSelector."beta\.kubernetes\.io/os"=linux \
#     --set controller.admissionWebhooks.patch.nodeSelector."beta\.kubernetes\.io/os"=linux

# az network firewall nat-rule create --collection-name exampleset --destination-addresses $FWPUBLIC_IP --destination-ports 80 --firewall-name $FWNAME --name inboundrule --protocols Any --resource-group $RG --source-addresses '*' --translated-port 80 --action Dnat --priority 100 --translated-address $SERVICE_IP

aks-cluster:
	az aks create \
		--resource-group $(RESOURCE_GROUP_NAME) \
		--name $(AKS_CLUSTER) \
		--node-count 3 \
		--generate-ssh-keys \
		--service-cidr 10.254.0.0/16 \
		--dns-service-ip 10.254.0.10 \
		--docker-bridge-address 172.17.0.1/16 \
		--vnet-subnet-id $(SUBNET_ID) \
		--service-principal $(SP_ID) \
		--client-secret $(SP_PASSWORD) \
		--network-plugin azure \
		--network-policy azure \
		--outbound-type userDefinedRouting

network-role:
	az role assignment create --assignee $(SP_ID) --scope $(VNET_ID) --role "Network Contributor"
