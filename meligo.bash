#!/bin/bash

WEBAPP_NAME_TEST="webApp-test1296bc4c"
RESOURCE_GROUP_TEST="rg-testc7776f6f"

alias meligo_test_tail="az webapp log tail --name $WEBAPP_NAME_TEST --resource-group $RESOURCE_GROUP_TEST"
alias meligo_test_backend_tail="az webapp log tail --name api-tm8s-plan-test-001 --resource-group rg-tm8s-plan-test-001"

WEBAPP_NAME_PROD="webApp-prode8ec71a7"
RESOURCE_GROUP_PROD="rg-prode406d490"

alias meligo_prod_tail="az webapp log tail --name $WEBAPP_NAME_PROD --resource-group $RESOURCE_GROUP_PROD"
alias meligo_prod_backend_tail="az webapp log tail --name api-tm8s-plan-stage-001 --resource-group rg-tm8s-plan-stage-001"

