FROM elasticsearch:2.3.0

WORKDIR /usr/share/elasticsearch

RUN plugin install analysis-kuromoji
RUN plugin install mobz/elasticsearch-head
RUN plugin install polyfractal/elasticsearch-inquisitor

COPY ./config ./config
