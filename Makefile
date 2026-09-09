.PHONY: fmt validate test lint check plan-dev plan-prod clean

# Everything CI runs, runnable locally in one command.
check: fmt validate test

fmt:
	terraform fmt -recursive -check -diff

validate:
	terraform init -backend=false
	terraform validate
	@for dir in modules/*/; do \
		echo "==> $$dir"; \
		terraform -chdir="$$dir" init -backend=false; \
		terraform -chdir="$$dir" validate; \
	done

# Mocked providers: no AWS account, no credentials.
test:
	terraform test

lint:
	tflint --init
	tflint --recursive --format compact

# These need real credentials.
plan-dev:
	terraform plan -var-file=environments/dev/terraform.tfvars

plan-prod:
	terraform plan -var-file=environments/prod/terraform.tfvars

clean:
	find . -type d -name .terraform -exec rm -rf {} + 2>/dev/null || true
	rm -f .terraform.lock.hcl modules/*/.terraform.lock.hcl
