You need to alter 03-cluster.yaml to use the IP address of
the nfs service that was created, directly.

Just like other problems with a registry pod that I tried
to create earlier, during pod creation the DNS service
is simply not available and is more like the host machine
launching the container. Therefore, each time the service
is torn down, and a new IP is assigned when it is brought
back up, this file must be edited and fixed.

## TODO 1
The above could easily be scripted at some point, but leaving that for later...

## TODO 2
Maybe need to resolve the unamed group error when using
Bitnami OpenLDAP. It doesn't really impact anything, but
it's annoying to see the warning all of the time.

