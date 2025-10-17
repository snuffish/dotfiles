#!/bin/bash

WEBAPP_NAME="MELIGO_TEST_WEBAPP"
RESORUCE_GROUP="MELIGO_TEST_RG"
alias meligo_test_tail="az webapp log tail --name $WEBAPP_NAME --resource-group $RESORUCE_GROUP"

alias meligo_backend_tail="az webapp log tail --name MELIGO_TEST_API --resource-group MELIGO_TEST_API_RG"
