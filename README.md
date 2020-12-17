# A Stateful Open Liberty application in Kubernetes

Demo a stateful Liberty app in Kubernetes (because lots of apps are stateful).  The first part shows in-memory session replication using Hazelcast.  There is no session affinity.  The second part adds nginx Ingress to provide session affinity based on the JSESSIONID Cookie.  The third part shows how to externalize the transaction logs such that they can be recovered after a server crash.  Note, this uses StatefulSets to give us fixed hostnames (the Pod name) required for recovery, and a Persistent Volume to store the transaction logs.

***WARNING: the configuration here is suitable for demo purposes to introduce the concepts, but is not sufficient for a production deployment.  For example, the persistent volume is only accessible on a single Node.***

The core Sessions/Hazelcast application is derived from the Open Liberty Guide on Sessions.

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

Alternatively you can use the OpenAPI UI by pointing your browser at
```
http://localhost:9080/openapi/ui/
```

Stop in Docker
```
docker ps
docker stop <container id>
```

Deploy to Kube, exposed via NodePort
```
kubectl apply -f kube-stateful-app.yaml
```

Let's see if session affinity is working

Let's put something in the cart
```
curl --cookie-jar cookies.txt -X POST "http://localhost:31000/stateful-app/cart/Flying%20Saucers&2.34" -H "accept: */*"
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

# Storing transaction logs outside the container for recovery

Before you begin, you'll want to change the location on the host where the trans logs will be stored.  This is in the file `kube-statefulset-app-persistence.yaml`.

If they're running, stop the pods
```
kubectl delete -f kube-stateful-app.yaml
```

Configure the persistent volume and persistent volume claim for the transaction logs
```
kubectl apply -f kube-statefulset-app-persistence.yaml
```

Deploy the pods that use a StatefulSet to give them fixed pod names
```
kubectl apply -f kube-statefulset-app.yaml
```

Look in the directory on the host where the tran logs are now stored
```yaml
  hostPath:
    path: "/Users/charters/temp/demo-trans-storage"
```

Take a look at the logs for one of the pods
```
kubectl exec -it cart-deployment-0 -- cat /logs/messages.log
```

Note there are messages saying there aren't any logs and so Liberty creates them
```
[12/15/20 16:51:28:165 UTC] 00000038 com.ibm.ws.recoverylog.spi.LogHandle                         I CWRLS0007I: No existing recovery log files found in /opt/ol/wlp/output/defaultServer/tranlog/cart-deployment-0/tranlog. Cold starting the recovery log.
[12/15/20 16:51:28:167 UTC] 00000038 com.ibm.ws.recoverylog.spi.LogFileHandle                     I CWRLS0006I: Creating new recovery log file /opt/ol/wlp/output/defaultServer/tranlog/cart-deployment-0/tranlog/log1.
[12/15/20 16:51:28:183 UTC] 00000038 com.ibm.ws.recoverylog.spi.LogFileHandle                     I CWRLS0006I: Creating new recovery log file /opt/ol/wlp/output/defaultServer/tranlog/cart-deployment-0/tranlog/log2.
```

Kill one of the pods
```
kubectl delete pod cart-deployment-0
```

Take a look at the logs for one of the pods
```
kubectl exec -it cart-deployment-0 -- cat /logs/messages.log
```

Note now the messages only talk about recovery
```
[12/15/20 16:52:52:694 UTC] 00000025 com.ibm.ws.recoverylog.spi.RecoveryDirectorImpl              I CWRLS0012I: All persistent services have been directed to perform recovery processing for this WebSphere server (defaultServer).
[12/15/20 16:52:52:695 UTC] 00000036 com.ibm.tx.jta.impl.RecoveryManager                          I WTRN0135I: Transaction service recovering no transactions.
```
