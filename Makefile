.PHONY: help compile recompile run run-mock test open clean all dev dev-refresh preview

# ------------------------------------------------------------------------------
# CONFIGURATION
# ------------------------------------------------------------------------------

.DEFAULT_GOAL := help

-include Makefile.local

WORKFLOW_ID   := incident-sunburst-plot
WORKFLOW_DIR  ?= ecoscope-workflows-incident-sunburst-plot-workflow
PARAM_FILE    ?= param.yaml
OUTPUT_DIR    ?= /tmp/incident-sunburst-plot/output
CASE          ?= wd-all-incidents

# Mock-IO data lives in this repo (mock-io/), not in ecoscope's synthetic example.
MOCK_IO_DIR   ?= $(CURDIR)/mock-io
export WT_TASK_MOCK_IO__ECOSCOPE_PLATFORM_TASKS_IO_GET_INCIDENT_EVENTS ?= $(MOCK_IO_DIR)/get-incident-events.example-return.parquet

# ------------------------------------------------------------------------------
# AESTHETICS & THEME
# ------------------------------------------------------------------------------

VIOLET     := \033[38;5;183m
SKY_BLUE   := \033[38;5;111m
MINT_GREEN := \033[38;5;114m
AQUA       := \033[38;5;123m
PEACH      := \033[38;5;216m
CORAL      := \033[38;5;210m
ROSE       := \033[38;5;218m
SLATE      := \033[38;5;246m
GOLD       := \033[38;5;222m
RESET      := \033[0m
BOLD       := \033[1m

T_TOP     := ╭────────────────────┬────────────────────────────────────────────────╮
T_MID     := ├────────────────────┼────────────────────────────────────────────────┤
T_BOT     := ╰────────────────────┴────────────────────────────────────────────────╯
B_TOP     := ╭───────────────────────────────────────────────────────────────╮
B_BOT     := ╰───────────────────────────────────────────────────────────────╯
SEPARATOR := ───────────────────────────────────────────────────────────────

define print_row
	@printf "$(VIOLET)│$(RESET)  $(SLATE)%-16s$(RESET)  $(VIOLET)│$(RESET)  $(AQUA)%-44s$(RESET)  $(VIOLET)│$(RESET)\n" "$(1)" "$(2)"
endef

define print_head
	@echo ""
	@echo " $(BOLD)$(3)$(1)  $(2)$(RESET)"
	@echo " $(SLATE)$(SEPARATOR)$(RESET)"
endef

# ------------------------------------------------------------------------------
# TARGETS
# ------------------------------------------------------------------------------

help: ## Show this help menu
	@echo ""
	@echo "$(VIOLET)$(T_TOP)$(RESET)"
	@printf "$(VIOLET)│$(RESET)  $(BOLD)$(SKY_BLUE)%-16s$(RESET)  $(VIOLET)│$(RESET)  $(BOLD)$(SKY_BLUE)%-44s$(RESET)  $(VIOLET)│$(RESET)\n" "Target" "Description"
	@echo "$(VIOLET)$(T_MID)$(RESET)"
	@awk 'BEGIN {FS = ":.*##"} /^[a-zA-Z_-]+:.*?##/ { printf "$(VIOLET)│$(RESET)  $(MINT_GREEN)%-16s$(RESET)  $(VIOLET)│$(RESET)  $(SLATE)%-44s$(RESET)  $(VIOLET)│$(RESET)\n", $$1, $$2 }' $(MAKEFILE_LIST)
	@echo "$(VIOLET)$(T_BOT)$(RESET)"
	@echo ""
	@echo "  $(SLATE)Override defaults in $(AQUA)Makefile.local$(RESET)  e.g.  $(AQUA)PARAM_FILE=test-cases/case1/param.yaml$(RESET)"
	@echo ""

all: compile run ## Compile, then run the workflow

WTC_PY       ?= pixi run python
DEV_MODE     ?= skip-solve

dev: ## Fast dev compile: cached env + local ecoscope (editable). Do not commit the output.
	@if [ -d $(WORKFLOW_DIR)/.pixi ]; then mv $(WORKFLOW_DIR)/.pixi .pixi-workflow-keep; fi; \
	WTC_DEV_MODE=$(DEV_MODE) $(WTC_PY) dev/wtc_dev.py compile --spec spec.yaml \
		--pkg-name-prefix=ecoscope-workflows \
		--results-env-var=ECOSCOPE_WORKFLOWS_RESULTS \
		--env-overrides wt-compiler-env-overrides.toml --clobber --no-progress; \
	rc=$$?; \
	if [ -d .pixi-workflow-keep ]; then mkdir -p $(WORKFLOW_DIR); mv .pixi-workflow-keep $(WORKFLOW_DIR)/.pixi; fi; \
	exit $$rc

dev-refresh: ## Like dev, but re-solve so newer package releases are picked up
	@$(MAKE) --no-print-directory dev DEV_MODE=persistent-env

recompile: ## Compile spec and update workflow env (faster)
	@echo ""
	@echo "$(VIOLET)➜ $(BOLD)Recompiling spec.yaml...$(RESET)"
	@pixi run recompile-incident-sunburst-plot
	@echo ""
	@echo "$(MINT_GREEN)✔ Recompile complete$(RESET)"

compile: ## Compile spec and install workflow env
	@echo ""
	@echo "$(VIOLET)➜ $(BOLD)Compiling spec.yaml...$(RESET)"
	@pixi run compile-incident-sunburst-plot
	@echo ""
	@echo "$(MINT_GREEN)✔ Compile complete$(RESET)"

setup: ## Create output directory
	$(call print_head,⚙,Setting up Environment,$(VIOLET))
	@mkdir -p $(OUTPUT_DIR)
	@echo "  $(MINT_GREEN)✔$(RESET) $(SLATE)Output directory ready:$(RESET) $(OUTPUT_DIR)"

run: setup ## Run the workflow with param.yaml (real data — no mock IO)
	@echo ""
	@echo "$(VIOLET)$(T_TOP)$(RESET)"
	@printf "$(VIOLET)│$(RESET)  $(BOLD)$(SKY_BLUE)%-16s$(RESET)  $(VIOLET)│$(RESET)  $(BOLD)$(SKY_BLUE)%-44s$(RESET)  $(VIOLET)│$(RESET)\n" "Settings" ""
	@echo "$(VIOLET)$(T_MID)$(RESET)"
	$(call print_row,Workflow,$(WORKFLOW_ID))
	$(call print_row,Params,$(PARAM_FILE))
	$(call print_row,Output,$(OUTPUT_DIR))
	$(call print_row,Exec Mode,sequential)
	@echo "$(VIOLET)$(T_BOT)$(RESET)"
	$(call print_head,🚀,Execution Log,$(PEACH))
	@cd $(WORKFLOW_DIR) && \
	ECOSCOPE_WORKFLOWS_RESULTS="file://$(OUTPUT_DIR)" \
	pixi run ecoscope-workflows-incident-sunburst-plot-workflow run \
		--config-file $(abspath $(PARAM_FILE)) \
		--execution-mode sequential \
		--no-mock-io
	@echo ""
	@echo "$(MINT_GREEN)$(B_TOP)$(RESET)"
	@printf "$(MINT_GREEN)│$(RESET)   $(BOLD)$(MINT_GREEN)✨  Workflow Completed Successfully$(RESET)                         $(MINT_GREEN)│$(RESET)\n"
	@echo "$(MINT_GREEN)$(B_BOT)$(RESET)"
	$(call print_head,📂,Output Directory Contents,$(CORAL))
	@eza -lha --group-directories-first --icons $(OUTPUT_DIR) 2>/dev/null || ls -lh $(OUTPUT_DIR)
	$(call print_head,📃,Result JSON Preview,$(ROSE))
	@if [ -f "$(OUTPUT_DIR)/result.json" ]; then \
		python3 -c "import json; r=json.load(open('$(OUTPUT_DIR)/result.json')); print('error:', r.get('error'))"; \
	else \
		echo "$(GOLD)⚠ result.json not found$(RESET)"; \
	fi
	@echo ""

run-mock: setup ## Run the workflow on the mock data in mock-io/ and preview it
	@cd $(WORKFLOW_DIR) && \
	ECOSCOPE_WORKFLOWS_RESULTS="file://$(OUTPUT_DIR)" \
	pixi run ecoscope-workflows-incident-sunburst-plot-workflow run \
		--config-file $(abspath $(PARAM_FILE)) \
		--execution-mode sequential \
		--mock-io
	@python3 dev/preview_dashboard.py $(OUTPUT_DIR) $(PREVIEW_FLAGS)

test: ## Run the compiled workflow's tests for one case (CASE=wd-all-incidents)
	$(call print_head,🧪,Testing case $(CASE),$(AQUA))
	@cd $(WORKFLOW_DIR) && pixi run -e test test-app-metadata --case $(CASE)
	@cd $(WORKFLOW_DIR) && pixi run -e test test-cli-sequential-mock-io --case $(CASE)
	@echo ""

open: ## Open all HTML outputs in the browser
	$(call print_head,🌐,Opening Outputs,$(AQUA))
	@ls -t $(OUTPUT_DIR)/*.html | xargs open
	@echo ""

refresh: ## Clear rattler package cache for a clean rebuild
	$(call print_head,🔄,Clearing Rattler Cache,$(GOLD))
	@rm -rf ~/Library/Caches/rattler/cache/pkgs/.icu-* ~/Library/Caches/rattler/cache/pkgs/icu-*
	@rm -rf ~/Library/Caches/rattler/cache/pkgs/.python-3* ~/Library/Caches/rattler/cache/pkgs/python-3*
	@echo "  $(MINT_GREEN)✔$(RESET) $(SLATE)Cache cleared — run$(RESET) $(AQUA)make compile$(RESET) $(SLATE)to rebuild$(RESET)"
	@echo ""

clean: ## Clean output directory
	$(call print_head,🗑️,Cleaning Output,$(PEACH))
	@rm -rf $(OUTPUT_DIR)
	@echo "  $(ROSE)✔ Deleted:$(RESET) $(SLATE)$(OUTPUT_DIR)$(RESET)"
	@echo ""
