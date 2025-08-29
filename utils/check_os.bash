#!/bin/bash

# Which OS am I using
unameOut="$(uname -s)"
case "${unameOut}" in
    Linux*)     OS=Linux;;
    Darwin*)    OS=Mac;;
    CYGWIN*)    OS=Mygwin;;
    MINGW*)     OS=MinGw;;
    *)          OS="UNKNOWN:${unameOut}"
esac

export OS
