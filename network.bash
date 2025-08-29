#!/bin/bash

alias localip="ip -json route get 8.8.8.8 | jq -r '.[].prefsrc'"

