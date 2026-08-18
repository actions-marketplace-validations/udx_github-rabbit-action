SHELL := /bin/bash

.PHONY: test validate-shell validate-shellcheck validate-action validate-workflow validate-release-version

test: validate-shell validate-shellcheck validate-action validate-workflow validate-release-version
	tests/run-merge-tests.sh

validate-shell:
	bash -n \
		bin/merge-configs.sh \
		bin/resolve-lifecycle.sh \
		bin/render-plan-summary.sh \
		bin/lib/config.sh \
		bin/lib/discovery.sh \
		bin/lib/github.sh \
		bin/lib/lifecycle.sh \
		bin/lib/validation.sh \
		bin/lib/environment.sh \
		bin/lib/logging.sh \
		bin/lib/merge.sh \
		bin/lib/output.sh \
		tests/run-merge-tests.sh

validate-shellcheck:
	shellcheck --external-sources --severity=error \
		bin/merge-configs.sh \
		bin/resolve-lifecycle.sh \
		bin/render-plan-summary.sh \
		bin/lib/config.sh \
		bin/lib/discovery.sh \
		bin/lib/environment.sh \
		bin/lib/github.sh \
		bin/lib/lifecycle.sh \
		bin/lib/logging.sh \
		bin/lib/merge.sh \
		bin/lib/output.sh \
		bin/lib/validation.sh \
		tests/run-merge-tests.sh

validate-action:
	yq eval '.' action.yml >/dev/null

validate-workflow:
	yq eval '.' .github/workflows/ci.yml >/dev/null
	yq eval '.' .github/workflows/release.yml >/dev/null
	yq eval '.' .github/workflows/publish-release.yml >/dev/null

validate-release-version:
	jq empty package.json
	release_version="$$(jq -r '.version // empty' package.json)"; \
	if [[ ! "$$release_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$$ ]]; then \
		echo "package.json version must be semantic, got: $$release_version" >&2; \
		exit 1; \
	fi; \
	changelog_tag="$$(awk '/^## v[0-9]+\.[0-9]+\.[0-9]+ - / { print $$2; exit }' CHANGELOG.md)"; \
	if [[ "$$changelog_tag" != "v$$release_version" ]]; then \
		echo "The first semantic CHANGELOG.md heading must match package.json version ($$release_version), got: $${changelog_tag:-missing}" >&2; \
		exit 1; \
	fi
