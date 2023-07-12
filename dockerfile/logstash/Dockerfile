# https://github.com/elastic/logstash-docker
FROM docker.elastic.co/logstash/logstash-oss:7.5.2

# Add your logstash plugins setup here
# Example: RUN logstash-plugin install logstash-filter-json
#Run logstash-plugin install logstash-codec-sflow logstash-codec-collectd logstash-output-websocket
RUN logstash-plugin install logstash-codec-sflow logstash-codec-collectd
RUN logstash-plugin install --version 3.0.5 logstash-output-websocket

COPY conf/logstash/pipeline/. /usr/share/logstash/pipeline/
COPY conf/logstash/logstash.yml /usr/share/logstash/config/
COPY conf/logstash/types.db /usr/share/logstash/
COPY conf/logstash/default-template.json /usr/share/logstash/