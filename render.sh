#!/usr/bin/env bash

DATA=$(JSONNET_PATH=vendor jsonnet $1 | jq .)
printf "%s\n" "$DATA"