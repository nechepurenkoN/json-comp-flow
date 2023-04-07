#!/bin/bash

pip install --target ../lambda/generator/deps boto3
pip install --target ../lambda/comparator/deps boto3
pip install --target ../lambda/comparator/deps deepdiff