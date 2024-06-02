#!/bin/bash

# Variables
RESOURCE_GROUP="1-b53d2dda-playground-sandbox"
LOCATION="eastus"
VNET_NAME="internship2024wro_VNet"
SUBNET_NAME="internship2024wro_Subnet"
ACR_NAME="internship2024wro_acr"
VM_NAME="internship2024wro_VM"
VM_SIZE="Standard_B1s"
NSG_NAME="interhship2024wro_nsg"
ACR_NAME="internship2024wro_acr"

az group create --name $RESOURCE_GROUP --location $LOCATION
echo "Resource Group $RESOURCE_GROUP created."

az network vnet create --resource-group $RESOURCE_GROUP --name $VNET_NAME --address-prefix 10.0.0.0/16 --subnet-name $SUBNET_NAME --subnet-prefix 10.0.1.0/24
echo "VNet $VNET_NAME with Subnet $SUBNET_NAME created."

az acr create --resource-group $RESOURCE_GROUP --name $ACR_NAME --sku Basic --admin-enabled true
echo "Azure Container Registry $ACR_NAME created."

az login -u $username -p $password

TOKEN=$(az acr login --name $acr --expose-token --output tsv --query accessToken)
SERVER=$(az acr show --name $acr --query loginServer --output tsv)

docker login $SERVER -u $username -p $TOKEN 

docker pull mszymanski/spring-petclinic:latest

docker tag mszymanski/spring-petclinic:latest $SERVER/$acr

docker push $SERVER/$acr

az network public-ip create --resource-group $RESOURCE_GROUP --name ${VM_NAME}PublicIP
echo "Public IP address created."

az network nsg create --resource-group $RESOURCE_GROUP --name $NSG_NAME
echo "Network Security Group $NSG_NAME created."

az network nsg rule create --resource-group $RESOURCE_GROUP --nsg-name $NSG_NAME --name AllowSSH --protocol tcp --priority 1000 --destination-port-range 22 --access allow
echo "SSH rule created in NSG."

az vm create --resource-group $RESOURCE_GROUP --name $VM_NAME --image UbuntuLTS --size $VM_SIZE --admin-username azureuser --generate-ssh-keys --vnet-name $VNET_NAME --subnet $SUBNET_NAME --public-ip-address ${VM_NAME}PublicIP --nsg $NSG_NAME --custom-data cloud-init-docker.yml
echo "VM $VM_NAME created."

IP_ADDRESS=$(az vm show --show-details --resource-group $RESOURCE_GROUP --name $VM_NAME --query [publicIps] --output tsv)

az vm run-command invoke --command-id RunShellScript --name $VM_NAME --resource-group $RESOURCE_GROUP --scripts "curl -fsSL https://get.docker.com -o get-docker.sh && sudo sh get-docker.sh"
echo "Docker installed on VM $VM_NAME."

az vm run-command invoke --command-id RunShellScript --name $VM_NAME --resource-group $RESOURCE_GROUP --scripts "sudo docker login $ACR_LOGIN_SERVER -u $(az acr credential show --name $ACR_NAME --query username -o tsv) -p $(az acr credential show --name $ACR_NAME --query passwords[0].value -o tsv) && sudo docker run -d -p 8080:8080 $ACR_LOGIN_SERVER/$DOCKER_IMAGE"
echo "Container running on VM $VM_NAME."

