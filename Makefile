DEFAULT_ENV_FILE := .env
ifneq ("$(wildcard $(DEFAULT_ENV_FILE))","")
include ${DEFAULT_ENV_FILE}
export $(shell sed 's/=.*//' ${DEFAULT_ENV_FILE})
endif

ENV_FILE := .env.local
ifneq ("$(wildcard $(ENV_FILE))","")
include ${ENV_FILE}
export $(shell sed 's/=.*//' ${ENV_FILE})
endif


##################################

.PHONY: setup
setup: configure-rhoam setup-sandbox

##################################

.PHONY: setup-rhoam
setup-rhoam:
	./configure-rhoam.sh

##################################

.PHONY: setup-sandbox
setup-sandbox:
	./setup-sandbox.sh

##################################

.PHONY: cleanup
cleanup: cleanup-rhoam cleanup-sandbox

##################################

.PHONY: cleanup-rhoam
cleanup-rhoam:
	./cleanup-rhoam.sh

##################################

.PHONY: cleanup-sandbox
cleanup-sandbox:
	./cleanup-sandbox.sh

##################################
