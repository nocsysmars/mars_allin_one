# mars_allin_one
install mars in a node 
docker-compose  operation:
1. docker-compose -f docker-compose.yml up -d
2. docker-compose -f docker-compose.yml stop

NOTE: ElasticSearch need run ./setup_elasticsearch on host.

NOTE: elasticsearch only bind localhost, if you want to access from Internet, you shall change network.bind_host="0.0.0.0"

