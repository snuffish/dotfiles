#!/bin/bash

WEBAPP_NAME_TEST="MELIGO_TEST_WEBAPP"
RESOURCE_GROUP_TEST="MELIGO_TEST_RG"

alias meligo_test_tail="az webapp log tail --name $WEBAPP_NAME_TEST --resource-group $RESOURCE_GROUP_TEST"
alias meligo_test_backend_tail="az webapp log tail --name MELIGO_TEST_API --resource-group MELIGO_TEST_API_RG"

WEBAPP_NAME_PROD="MELIGO_PROD_WEBAPP"
RESOURCE_GROUP_PROD="MELIGO_PROD_RG"

alias meligo_prod_tail="az webapp log tail --name $WEBAPP_NAME_PROD --resource-group $RESOURCE_GROUP_PROD"
alias meligo_prod_backend_tail="az webapp log tail --name MELIGO_PROD_API --resource-group MELIGO_PROD_API_RG"

