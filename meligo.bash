#!/bin/bash

alias meligo_test_tail='az webapp log tail --name $MELIGO_TEST_WEBAPP_NAME --resource-group $MELIGO_TEST_RESOUCE_GROUP'
alias meligo_test_backend_tail="az webapp log tail --name MELIGO_TEST_API --resource-group MELIGO_TEST_API_RG"

alias meligo_prod_tail='az webapp log tail --name $MELIGO_PROD_WEBAPP_NAME --resource-group $MELIGO_PROD_RESOURCE_GROUP'
alias meligo_prod_backend_tail="az webapp log tail --name MELIGO_PROD_API --resource-group MELIGO_PROD_API_RG"

alias meligo.se_tail="az webapp log tail --name MELIGO_DEV_WEBAPP --resource-group MELIGO_DEV_RG"
