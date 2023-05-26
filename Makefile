.DEFAULT_GOAL = help

TEMPLATE_REPO := https://github.com/geekcell/template-terraform-module.git
UPDATABLE_TEMPLATE_FILES := .github/ docs/logo.md .editorconfig .gitignore .pref-commit-config.yaml .terraform-docs.yml .tflint.hcl LICENSE Makefile

#########
# SETUP #
#########
.PHONY: setup/run
setup/run: setup/install-tools pre-commit/install-hooks ## Install and setup necessary tools

.PHONY: setup/install-tools
setup/install-tools:	# Install required tools
ifeq (, $(shell which brew))
	@echo "No brew in $$PATH. Currently only brew is supported for installing tools."
else
	@brew install pre-commit terraform terraform-docs tflint
endif

.PHONY: setup/update-template
setup/update-template: ## Pull the latest template files from the main repo
	@git config remote.terraform-module-template.url >&- || git remote add terraform-module-template $(TEMPLATE_REPO)
	@git fetch terraform-module-template main
	@git checkout -p terraform-module-template/main $(UPDATABLE_TEMPLATE_FILES)

##############
# PRE-COMMIT #
##############
.PHONY: pre-commit/install-hooks
pre-commit/install-hooks:	## Install pre-commit git hooks script
	@git init
	@pre-commit install

.PHONY: pre-commit/run-all
pre-commit/run-all:	## Run pre-commit against all files
	@pre-commit run -a

########
# HELP #
########
.PHONY: help
help:	## Shows this help
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_\-\.\/]+:.*?## / {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)
