#!/bin/bash

alias dnr="dotnet run"
alias dnb="dotnet build"
alias dnt="dotnet test"

# VVS NUGET PAT
export VSS_NUGET_EXTERNAL_FEED_ENDPOINTS='{"endpointCredentials":[{"endpoint":"https://grutbildning.pkgs.visualstudio.com/_packaging/GR.Library/nuget/v3/index.json","username":"pat","password":"$GRUTBILDNING_NUGET_ACCESS_TOKEN"}]}'
