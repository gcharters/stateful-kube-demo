# stateful-kube-demo

Demo a stateful Liberty app in Kubernetes (because lots of apps are stateful).  The core Sessions/Hazelcast application is derived from the Open Liberty Guide on Sessions.

The following instructions were tested on Docker for Mac.

## Stateful sessions with Hazelcast in-memory session repliation

Build the app
```
mvn install
```

Build the docker image
```
docker build -t stateful-app:1.0-SNAPSHOT .
```

Start in Docker
```
docker run -p9080:9080 stateful-app:1.0-SNAPSHOT
```

Make a request
```
curl http://localhost:9080/stateful-app/cart
```

Stop in Docker
```
docker ps
docker stop <container id>
```

Deploy to Kube, exposed via NodePort
```
kubectl deploy -f kube-stateful-app.yaml
```

Let's see if session affinity is working

Get cookies for a get request and store them.
```
curl --cookie-jar cookies.txt http://localhost:31000/stateful-app/cart
```

View the coookies
```
cat cookies.txt
```

Fire 10 requests at the service
```
for i in `seq 1 10`; \
do \
    curl --cookie cookies.txt http://localhost:31000/stateful-app/cart; \
    printf "\n"; \
done
```
Note the 'random' pod usage (no affinity)

## Session affinity (sticky sessions) with Nginx Ingress

Now deploy the nginx Ingress with session affinity for JSESSIONID.  Note, to get this to work, you may need to install the nginx Ingress support - see https://kubernetes.github.io/ingress-nginx/deploy/
```
kubectl apply -f kube-nginx-ingress.yaml
```

Fire 10 requests at the service
```
for i in `seq 1 10`; \
do \
    curl --cookie cookies.txt http://localhost/stateful-app/cart; \
    printf "\n"; \
done
```
Note they all get routed to the same pod.

Kill the pod that's running the instance we're being routed to
```
kubectl delete pod <podname>
```

Fire 10 more requests at the services.  
```
for i in `seq 1 10`; \
do \
    curl --cookie cookies.txt http://localhost/stateful-app/cart; \
    printf "\n"; \
done
```
Note we're routed to a different instance but still have session affinity.  Note the session is preserved because it was replicated to all instances using Hazelcast.

