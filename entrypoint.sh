#!/bin/bash

bundle exec puma -p 4223 -e production -w 2 -t 8:32
