# https://github.com/elastic/logstash-docker
FROM docker.elastic.co/logstash/logstash-oss:7.5.2

# Add your logstash plugins setup here
# Example: RUN logstash-plugin install logstash-filter-json
#Run logstash-plugin install logstash-codec-sflow logstash-codec-collectd logstash-output-websocket
RUN logstash-plugin install logstash-codec-sflow logstash-codec-collectd
RUN logstash-plugin install --version 3.0.5 logstash-output-websocket
