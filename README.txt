Build service
    docker-compose Build

Run 
    docker-compose run -p 5000:5000 service

Access data base graphic utilitary:
    http://localhost:8080

See app:
    http://localhost:5000


Remove containers:
    docker-compose rm -v

Remove volume data:
    docker volume rm proiect_db_data --force