OPERATOR_REPO?=https://github.com/rancher/elemental-operator
OPERATOR_BRANCH?=main
V_OFFSET?=no
V_PARSE?=patch

.PHONY: prepare-operator
prepare-operator:
	./builders/elemental-operator.sh $(OPERATOR_REPO) $(OPERATOR_BRANCH) $(V_PARSE) $(V_OFFSET)
