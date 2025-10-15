.PHONY: help test coverage badge install-hooks clean

help: ## Show this help message
	@echo 'Usage: make [target]'
	@echo ''
	@echo 'Available targets:'
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-15s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

test: ## Run all tests
	dart test

coverage: ## Run tests with coverage and generate report
	@echo "🧪 Running tests with coverage..."
	@dart test --coverage=coverage
	@dart pub global activate coverage
	@dart pub global run coverage:format_coverage --lcov --in=coverage --out=coverage/lcov.info --report-on=lib
	@echo "✅ Coverage data generated at coverage/lcov.info"

badge: coverage ## Update coverage badge
	@echo "🎨 Updating coverage badge..."
	@dart run tool/update_coverage_badge.dart

badge-sh: coverage ## Update coverage badge (using bash script)
	@./tool/update_coverage_badge.sh

install-hooks: ## Install git pre-commit hook for automatic badge updates
	@echo "📦 Installing pre-commit hook..."
	@cp tool/pre-commit .git/hooks/pre-commit
	@chmod +x .git/hooks/pre-commit
	@echo "✅ Pre-commit hook installed successfully!"
	@echo "   Badge will auto-update when you commit test/source changes"

html-report: coverage ## Generate HTML coverage report and open it
	@echo "📊 Generating HTML coverage report..."
	@genhtml coverage/lcov.info -o coverage/html
	@echo "✅ HTML report generated at coverage/html/index.html"
	@if [ "$$(uname)" = "Darwin" ]; then \
		open coverage/html/index.html; \
	elif [ "$$(uname)" = "Linux" ]; then \
		xdg-open coverage/html/index.html; \
	fi

coverage-summary: coverage ## Show coverage summary
	@echo "📈 Coverage Summary:"
	@lcov --summary coverage/lcov.info

clean: ## Clean coverage and build artifacts
	@echo "🧹 Cleaning up..."
	@rm -rf coverage/
	@rm -rf .dart_tool/
	@rm -rf build/
	@echo "✅ Cleanup complete"

format: ## Format Dart code
	@dart format .

analyze: ## Analyze Dart code
	@dart analyze

check: format analyze test ## Run format, analyze, and test

all: clean check badge html-report ## Run complete workflow: clean, check, and generate reports

