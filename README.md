ES Workshop
===========

Setup
-----

```sh
# Setup environment
$ cp .env{.sample,}
$ docker login
$ make deps

# Setup Elasticsearch
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
