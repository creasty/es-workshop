ES Workshop
===========

Setup
-----

```sh
# Setup environment
$ docker login
$ make deps

# Setup Elasticsearch
$ cp .env{.sample,}
$ vim .env  # set ELASTICSEARCH_URL to a proper endpoint
$ make start
$ make index
```


Development
-----------

```sh
# Open "head"
$ open "http://$(docker-machine ip $vm_name):9200/_plugin/head"

# Run main.rb
$ make run
```
