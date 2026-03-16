#!/bin/bash

alias meligo_test_tail='az webapp log tail --name $MELIGO_TEST_WEBAPP_NAME --resource-group $MELIGO_TEST_RESOUCE_GROUP'
alias meligo_test_backend_tail="az webapp log tail --name api-tm8s-plan-test-001 --resource-group rg-tm8s-plan-test-001"

alias meligo_prod_tail='az webapp log tail --name $MELIGO_PROD_WEBAPP_NAME --resource-group $MELIGO_PROD_RESOURCE_GROUP'
alias meligo_prod_backend_tail="az webapp log tail --name api-tm8s-plan-stage-001 --resource-group rg-tm8s-plan-stage-001"

alias meligo.se_tail="az webapp log tail --name webapp-devb286d811 --resource-group rg-dev225ef1fe"
