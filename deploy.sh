#!/bin/bash
#Login to the Docker Hub
function dockerLogin() {
	is_login=`cat ~/.docker/config.json | jq -r ".auths[].auth"`
	if [ -z $is_loggged_in]:
	then
		echo "######################Please login to the Docker Hub##############################"
		docker login
	fi
}
#Docker volumes
function rmVolumes(){
	for i in $(docker volume ls | awk '{ print$2 }' | grep -v "VOLUME")
	do
		docker volume rm $i 2>/dev/null
	done
}

#Deploying wp-blog with k8s

cd /var/www/html/optiblog/kube_deploy
#Deploying volume and wordpress
kubectl apply -f wp-volume.yaml 
kubectl apply -f wp.yaml
#Creating service for the loadbalancing wordpress side
kubectl apply -f wp-service.yaml
kubectl get svc | cat wordpress-service && cat CLUSTER_IP


#Checking if containers are exists
check_flask=$(docker ps -f name=flask | awk '{ print$7 }' | tail -n1 | grep -v PORTS)
flask_id=$(docker ps -f name=flask | awk '{ print$1 }' | grep -v CONTAINER)
check_elasticsearch=$(docker ps -f name=elasticsearch | awk '{ print$8 }' | tail -n1 | grep -v PORTS)
elasticsearch_id=$(docker ps -f name=elasticsearch | awk '{ print$1 }' | grep -v CONTAINER)
check_redis=$(docker ps -f name=redis | awk '{ print$8 }' | tail -n1 | grep -v PORTS)
redis_id=$(docker ps -f name=redis | awk '{ print$1 }' | grep -v CONTAINER)

if [[ "$check_flask == "Up"]]
then
	docker stop "$flask_id"
fi

if [[ "$check_elasticsearch == "Up"]]
then
	docker stop "$elasticsearch_id"
fi

#Looking for docker-compose files
if [[ -f "docker-compose.yml" ]]
then
	echo "Deleting docker-compose.yml file."
	sleep 1s
	sudo rm -rf docker-compose.yml
fi

if [[ -d "docker"]]
then
	echo "Deleting the docroot directory."
	sleep 1s
	sudo rm -rf docroot
fi

if [[ -d "elasticsearch"]]
then
	echo "Deleting the elasticsearch directory."
	sleep 1s
	sudo rm -rf elasticsearch
fi

sql_file=$(find . -name "*.sql")

for i in $sql_file
do
	if [[ -f $i ]]
	then
		echo "Removing $i"
		sleep 1s
		sudo rm -rf "$i"
	fi
done

#This command is needed for elasticsearch normal work
sudo /bin/su -c "echo 'vm.max_map_count=262144' >> /etc/sysctl.conf"
sudo sysctl -p

######################################
echo "Starting docker."
sudo systemctl start docker
sleep 3s

#Cloning project from the GitHub.
echo "##############Cloning project.....###############"
mkdir -p docroot
cd docroot
git clone git@github.com:mxsvdrgworks/optiblog.git .


echo "Starting the project....."
sudo docker network prune -f
sudo docker system prune -f
sudo docker volume prune -f

echo "Pulling....."
docker pull mxsvdrgworks/optiblog:v1
if [[ "$?" == 0 ]];
then
	echo "Successfully pulled the image."
else
	dockerLogin
fi

#Importing database
echo "Importing optiblog_db.sql"
pv optiblog_db.sql | mysql optiblog_db
sleep 2s
echo "Imports are finished."
else
	echo "Check the Mysql connection."
	exit 1
fi

#Building a flask image
cd /var/www/html/optiblog/app-flask
docker image build -t flask_docker2 .
docker run -d -p 8888:5000 flask_docker2

echo "#########################DEPLOY IS FINISHED##############################"
