# Single Opensearch server with dashboards

Access the Opensearch dashboard using the IP configured in settings.yaml on port 5601

```
http://192.168.50.51:5601
```

The [opensearch script](https://github.com/rerichardjr/vagrants/blob/main/opensearch/scripts/opensearch.sh) generates a random password using pwgen and saves it to /vagrant/password.txt.  This will be the password for the dashboard admin user.
