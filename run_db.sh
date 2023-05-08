#!/bin/bash

docker run --name=shop -e POSTGRES_PASSWORD="root" -e POSTGRES_DB="shop" -d -p 5432:5432 --rm postgres
