cd /dataarc
/usr/sbin/service mongodb start
/usr/sbin/service postgresql start

psql -c "create user dataarc with CREATEDB SUPERUSER PASSWORD 'docker' " -U postgres
echo "CREATE DB"
createdb -O dataarc dataarc -U postgres
echo "DONE CREATE DB"
# psql -c 'create database dataarc' -U dataarc -d template1
psql -c "CREATE EXTENSION postgis; CREATE EXTENSION postgis_topology"  -U postgres dataarc
echo "DONE CREATE EXTENSION"


mvn -q install -N -DskipTests
mvn clean compile -PloadTestData
mvn clean compile jetty:run