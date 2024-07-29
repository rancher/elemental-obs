REPO?=rancher/elemental-operator
BRANCH?=main
V_OFFSET?=no
V_PARSE?=patch

GH_REPO=https://github.com/$(REPO)

ifeq ("$(findstring elemental-operator, $(REPO))","elemental-operator")
BUILDER:=./builders/elemental-operator.sh
endif

.PHONY: prepare-sources
prepare-sources:
ifeq ("$(BUILDER)","")
	@echo "BUILDER paramter not defined"
	exit 1
else ifeq ("$(REPO)","")
	@echo "REPO paramter not defined"
	exit 1
else
	$(BUILDER) $(GH_REPO) $(BRANCH) $(V_PARSE) $(V_OFFSET)
endif

.PHONY: update-sources
update-sources:
	./builders/update-sources.sh
