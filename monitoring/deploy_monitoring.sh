#!/bin/bash
sudo docker swarm init
sudo docker stack deploy -c /home/optiblog/monitoring/docker-compose.yml monitoring

echo "Downloading and installing Node exporter for Grafana"
wget https://github.com/prometheus/node_exporter/releases/download/v*/node_exporter-*.*-amd64.tar.gz
tar xvfz node_exporter-*.*-amd64.tar.gz
cd node_exporter-*.*-amd64
sudo chmod +x node_exporter
./node_exporter
#Checking node_exporter
curl http://localhost:9100/metrics

echo "Writing changes to the Prometheus config....."
echo -e "\n- job_name: "node-exporter"\n    static_configs:\n      - targets: ['node-exporter:9100']" >> /var/lib/docker/volumes/monitoring_prom-configs/_data/prometheus.yml"
echo "Applying changes to the Prometheus configuration"
#sudo docker kill -s SIGHUP monitoring_prometheus*
sudo docker kill -s SIGHUP $(docker container ls -q --filter name=monitoring_prometheus*)

echo "##############################Deploying monitoring is finished######################"
