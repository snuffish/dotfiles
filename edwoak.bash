#!/bin/bash

# Meligo
alias start_api=".p && cd Meligo/tm8s-backend/tm8s && dotnet run --project tm8s.Plan.Api --launch-profile https"
alias watch_api=".p && cd Meligo/tm8s-backend/tm8s && dotnet watch --project tm8s.Plan.Api --launch-profile https"

# Dotnet EF
alias efdev="unset ASPNETCORE_ENVIRONMENT"
alias eftest="export ASPNETCORE_ENVIRONMENT=Test"
alias efstage="export ASPNETCORE_ENVIRONMENT=Staging"

efenv() {
  eval "echo \"=> $ASPNETCORE_ENVIRONMENT"\"
}

STARTUP_PROJECT="tm8s.Plan.Api"
PROJECT="tm8s.Form.Infrastructure"
CONTEXT="FormDbContext"
ADDED_FLAGS=""

evalAddedFlags() {
  export ADDED_FLAGS="--project $PROJECT --context $CONTEXT --startup-project $STARTUP_PROJECT"
}

efproject() {
  if [[ -z "$1" ]]; then
    echo "=> $PROJECT"
  else
    export PROJECT="tm8s.$1.Infrastructure"
  fi

  evalAddedFlags
}

efcontext() {
  if [[ -z "$1" ]]; then
    echo "=> $CONTEXT"
  else
    export CONTEXT="$1"
  fi

  evalAddedFlags
}

efaddmigrate() {
  evalAddedFlags
  eval "dotnet ef migrations add $1 $ADDED_FLAGS --json"
}

efremovemigrate() {
  evalAddedFlags
  echo "dotnet ef migrations remove $ADDED_FLAGS"
  eval "dotnet ef migrations remove $ADDED_FLAGS"
}

efupdatemigrate() {
  evalAddedFlags
  eval "dotnet ef database update $1 $ADDED_FLAGS"
}

evalAddedFlags
