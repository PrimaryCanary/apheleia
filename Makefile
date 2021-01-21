VERSION ?=
CMD ?=

SCRIPTDIR=scripts
TESTDIR=test

EMACS ?= emacs

# The order is important for compilation.
for_compile := *.el
for_checkdoc := *.el
for_longlines := $(wildcard *.el *.md *.yml) Makefile

.PHONY: help
help: ## Show this message
	@echo "usage:" >&2
	@grep -h "[#]# " $(MAKEFILE_LIST)	| \
		sed 's/^/  make /'		| \
		sed 's/:[^#]*[#]# /|/'		| \
		sed 's/%/LANG/'			| \
		column -t -s'|' >&2

.PHONY: lint
lint: compile checkdoc longlines ## Build project and run all linters

.PHONY: compile
compile: ## Check for byte-compiler errors
	@for file in $(for_compile); do \
	    echo "[compile] $$file" ;\
	    rm -f "$${file}c" ;\
	    $(EMACS) -Q --batch -L . -f batch-byte-compile $$file 2>&1 \
	        | grep -v "^Wrote" \
	        | grep . && exit 1 || true ;\
	done

.PHONY: checkdoc
checkdoc: ## Check for missing or poorly formatted docstrings
	@for file in $(for_checkdoc); do \
	    echo "[checkdoc] $$file" ;\
	    $(EMACS) -Q --batch \
	        --eval "(or (fboundp 'checkdoc-file) (kill-emacs))" \
	        --eval "(setq sentence-end-double-space nil)" \
	        --eval "(checkdoc-file \"$$file\")" 2>&1 \
	        | grep . && exit 1 || true ;\
	done

.PHONY: longlines
longlines: ## Check for lines longer than 79 characters
	@for file in $(for_longlines); do \
	    echo "[longlines] $$file" ;\
	    cat "$$file" \
	        | sed '/[l]onglines-start/,/longlines-stop/d' \
	        | grep -E '.{80}' \
	        | grep -E -v 'https?://' \
	        | sed "s/^/$$file:long line: /" \
	        | grep . && exit 1 || true ;\
	done

.PHONY: clean
clean: ## Remove build artifacts
	@echo "[clean]" *.elc
	@rm -f *.elc

.PHONY: docker
docker: ## Start a Docker shell; e.g. make docker VERSION=25.3
	@"$(SCRIPTDIR)"/docker.bash "$(VERSION)" "$(CMD)"

.PHONY: test
test: ## Run formatter test suite
	@cd "$(TESTDIR)" && find formatters -type f,l ! -name "*.formatted" | \
						xargs -n1 ./test-formatter.bash

$(TESTDIR)/%: ## Run test for specified formatter with make test/mode/formatter
	@FILE=$$(cd "$(TESTDIR)" && \
			 find formatters/ -type f,l -path *$*.* ! -name "*.formatted"); \
	if [ "$$FILE" != "" ]; then \
		cd "$(TESTDIR)" && ./test-formatter.bash "$$FILE"; \
	else \
		echo >&2 "Mode/formatter pair not found: $*"; \
		exit 1; \
	fi
