# https://github.com/elastic/logstash-docker
FROM docker.elastic.co/logstash/logstash-oss:6.1.0

# Add your logstash plugins setup here
# Example: RUN logstash-plugin install logstash-filter-json
Run logstash-plugin install logstash-codec-sflow logstash-codec-collectd logstash-output-websocket
