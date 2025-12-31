# Deploying mongodb pod using persistent volumes

is will create a [Deployment](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/) with 1 mongodb [pod](https://kubernetes.io/docs/concepts/workloads/pods/) using a [persistent volume](https://kubernetes.io/docs/concepts/storage/persistent-volumes/) on [namespace](https://kubernetes.io/docs/concepts/overview/working-with-objects/namespaces/) `persistentvolume`, this means that if I lose my pod, I will not lost my data.

*Note*: Usually when creating databases you will probably prefer rely on [statefulset](https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/) to have a stable name like rsvp-db-0 instead of a dynamic name create by deployment like rsvp-db-8564bb558c-zf2ff. But for the purpose of show that we have a different pod using same disk, I decide to prefer a Deployment.
Additionally to that, you can check our [persistentVolumeRWO.yaml](persistentVolumeRWO.yaml) file that the [access mode](https://kubernetes.io/docs/concepts/storage/persistent-volumes/#access-modes) is set to `ReadWriteOnce` to ensure that only one node at time will have access to this volume. This is a [restriction](https://github.com/kubernetes-sigs/kind/issues/3803) of StorageClass "standard" from kind.

## mongodb

[Official documentation about this image](https://hub.docker.com/_/mongo)

It will deploy 1 pod using [persistentVolumeRWO.yaml](persistentVolumeRWO.yaml)

```bash
kubectl apply -f persistentVolumeRWO.yaml
```

You can check that it is running using

```bash
kubectl -n persistentvolume get all
```

It will show something like this:

```bash
NAME                           READY   STATUS    RESTARTS   AGE
pod/rsvp-db-8564bb558c-zf2ff   1/1     Running   0          36s

NAME                      READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/rsvp-db   1/1     1            1           36s

NAME                                 DESIRED   CURRENT   READY   AGE
replicaset.apps/rsvp-db-8564bb558c   1         1         1       36s
```

*NOTE*: That not all resources appears here, for instance persistentvolumeclaim and persistentvolumes.

To see then you can use

```bash
kubectl -n persistentvolume get persistentvolume
kubectl -n persistentvolume get persistentvolumeclaims
```

Finally you can access using mongosh

```bash
kubectl -n persistentvolume exec -it pods/rsvp-db-8564bb558c-zf2ff -- bash
mongosh
```

Since I'm not expert on mongodb, I will just add some simple commands to create a new db with simple data so we can remove and recreate this pod and check that the data was not lost.

```mongosh
use mynewdb
db.user.insertOne({name: "Jane Doe", age: 25})
db.user.insertOne({name: "John Doe", age: 26})
```

Then to see our data

```mongosh
show dbs
```

*Note*: The created db it will appears

```
admin    40.00 KiB
config   92.00 KiB
local    72.00 KiB
mynewdb  72.00 KiB
```

```mongosh
show collections
var collections = db.getCollectionNames();
for(var i = 0; i< collections.length; i++) {    
   print('Collection: ' + collections[i]); // print the name of each collection
   db.getCollection(collections[i]).find().forEach(printjson); //and then print     the json of each of its elements
}
```

It will show a json format like this

```json
{
  _id: ObjectId('674b189ad93c586950c1c18c'),
  name: 'John Doe',
  age: 10
}
{
  _id: ObjectId('674b18c9d93c586950c1c18d'),
  name: 'Jane Doe',
  age: 15
}
```

Use `exit` until you return to your console outside of container.

Now let's delete our pod

```bash
kubectl -n persistentvolume delete pod/rsvp-db-8564bb558c-zf2ff
```

*Note*: Since we create it as replicaset/deployment, it will automatically create a new pod

So, let's access it and check if the data is there

```bash
kubectl -n persistentvolume exec -it pods/rsvp-db-8564bb558c-pvspq -- bash
mongosh
```

```mongosh
use mynewdb
show collections
var collections = db.getCollectionNames();
for(var i = 0; i< collections.length; i++) {    
   print('Collection: ' + collections[i]); // print the name of each collection
   db.getCollection(collections[i]).find().forEach(printjson); //and then print     the json of each of its elements
}
```

You will see our data is there.

Use `exit` until you return to your console outside of container.


## clean up

To clean up you can remove using this

```bash
kubectl delete -f persistentVolumeRWO.yaml
```
