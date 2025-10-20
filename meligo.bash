#!/bin/bash

WEBAPP_NAME="webApp-test1296bc4c"
RESORUCE_GROUP="rg-testc7776f6f"
alias meligo_test_tail="az webapp log tail --name $WEBAPP_NAME --resource-group $RESORUCE_GROUP"

alias meligo_backend_tail="az webapp log tail --name api-tm8s-plan-test-001 --resource-group rg-tm8s-plan-test-001"
