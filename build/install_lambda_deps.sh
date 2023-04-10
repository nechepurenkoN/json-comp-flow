#!/bin/bash

pip install --target ../lambda/generator/deps boto3 --upgrade
pip install --target ../lambda/comparator/deps boto3 --upgrade
pip install --target ../lambda/comparator/deps deepdiff --upgrade