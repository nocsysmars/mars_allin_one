# https://github.com/elastic/elasticsearch-docker
FROM docker.elastic.co/elasticsearch/elasticsearch-oss:7.9.0-amd64

# Add your elasticsearch plugins setup here
# Example: RUN elasticsearch-plugin install analysis-icu
RUN echo y | elasticsearch-plugin install org.codelibs:elasticsearch-dataformat:7.9.0
