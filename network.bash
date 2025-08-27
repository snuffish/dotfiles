#!/bin/bash

alias logcalip="ip -json route get 8.8.8.8 | jq -r '.[].prefsrc'"

