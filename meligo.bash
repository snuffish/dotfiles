#!/bin/bash

WEBAPP_NAME="MELIGO_TEST_WEBAPP"
RESORUCE_GROUP="MELIGO_TEST_RG"
alias meligo_test_tail="az webapp log tail --name $WEBAPP_NAME --resource-group $RESORUCE_GROUP"

