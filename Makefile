REPO?=rancher/elemental-operator
BRANCH?=main
V_OFFSET?=no
V_PARSE?=patch

GH_REPO=https://github.com/$(REPO)


.PHONY: prepare-sources
prepare-sources:
ifeq ("$(REPO)","")
	@echo "REPO paramter not defined"
	exit 1
else
	./scripts/prepare-sources.sh $(GH_REPO) $(BRANCH) $(V_PARSE) $(V_OFFSET)
endif

.PHONY: update-sources
update-sources:
	./scripts/update-sources.sh
