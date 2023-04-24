#!/bin/bash

# Get a list of all resources starting with "aws_s3"
RESOURCE_LIST=$(terraform state list | grep "^aws_iam")

# Loop through the list of resources and move each one to the new module
for RESOURCE in $RESOURCE_LIST; do
  terraform state mv $RESOURCE module.iam.$RESOURCE
done

