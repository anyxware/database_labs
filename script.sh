#!/bin/bash

psql postgresql://postgres:root@localhost:5432/shop -a -f $1
