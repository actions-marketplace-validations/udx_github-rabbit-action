#!/usr/bin/env bash
set -euo pipefail
#
# render-plan-summary.sh — Parse plan-summary.json into a markdown table
#
# Usage: render-plan-summary.sh <plan-summary.json> <output.md>
#
# Adapted from udx/gh-workflows infra-build.yml report job.
# Supports multiple JSON shapes: .plans object, nested objects with add/change/destroy counts.
#

summary_path="${1:-}"
markdown_path="${2:-}"
github_output="${GITHUB_OUTPUT:-}"

write_output() {
  if [[ -n "$github_output" ]]; then
    printf '%s=%s\n' "$1" "$2" >> "$github_output"
  fi
}

fail_closed() {
  write_output "has_plan_markdown" "false"
  write_output "has_plan_breakdown" "false"
  write_output "plan_breakdown_count" "0"
  write_output "total_add" "0"
  write_output "total_change" "0"
  write_output "total_destroy" "0"
}

if [[ -z "$summary_path" || -z "$markdown_path" || ! -f "$summary_path" ]]; then
  fail_closed
  exit 0
fi

if ! jq empty "$summary_path" >/dev/null 2>&1; then
  fail_closed
  exit 0
fi

rows_json="$(jq -c '
  def generic_keys:
    [
      "modules", "module", "services", "service", "items", "item",
      "entries", "entry", "details", "detail", "plans", "plan",
      "resources", "resource", "components", "component", "summary",
      "breakdown", "children"
    ];

  def has_counts:
    type == "object" and ((has("add")) or (has("change")) or (has("destroy")));

  def child_values:
    if type == "object" then .[]?
    elif type == "array" then .[]?
    else empty
    end;

  def has_nested_counts:
    [child_values | .. | objects | select(has_counts)] | length > 0;

  def explicit_label:
    [
      (
        if (.module? | type) == "string" and (.service? | type) == "string" then "\(.module)/\(.service)"
        elif (.module? | type) == "string" and (.id? | type) == "string" then "\(.module)/\(.id)"
        elif (.module? | type) == "string" and (.name? | type) == "string" then "\(.module)/\(.name)"
        elif (.service? | type) == "string" and (.id? | type) == "string" then "\(.service)/\(.id)"
        else empty
        end
      ),
      .label,
      .display_name,
      .displayName,
      .full_name,
      .fullName,
      .name,
      .module_service,
      .moduleService,
      .module_path,
      .modulePath,
      .module,
      .service,
      .resource,
      .resource_name,
      .resourceName,
      .id,
      .key,
      .path
    ]
    | map(select(type == "string" and length > 0))
    | first;

  def normalized_path($path):
    $path
    | map(tostring)
    | map(select(. != "total"))
    | map(select(test("^[0-9]+$") | not))
    | map(select((generic_keys | index(.)) | not));

  . as $root
  | {
      total: {
        add: (.total.add // 0),
        change: (.total.change // 0),
        destroy: (.total.destroy // 0)
      },
      rows:
        (
          (
            if (.plans | type) == "object" then
              [
                .plans
                | to_entries[]
                | {
                    label: .key,
                    add: (.value.add // 0),
                    change: (.value.change // 0),
                    destroy: (.value.destroy // 0)
                  }
              ]
            else
              [
                paths(objects) as $path
                | (getpath($path)) as $node
                | select($node | has_counts)
                | select(($node | has_nested_counts) | not)
                | {
                    label: (($node | explicit_label) // ((normalized_path($path) | join(" / ")) // "Unlabeled component")),
                    add: ($node.add // 0),
                    change: ($node.change // 0),
                    destroy: ($node.destroy // 0)
                  }
              ]
            end
          )
          | map(select(.label != "Unlabeled component" or .add != ($root.total.add // 0) or .change != ($root.total.change // 0) or .destroy != ($root.total.destroy // 0)))
          | reduce .[] as $row ({}; .[$row.label] = {
              label: $row.label,
              add: ((.[$row.label].add // 0) + ($row.add // 0)),
              change: ((.[$row.label].change // 0) + ($row.change // 0)),
              destroy: ((.[$row.label].destroy // 0) + ($row.destroy // 0))
            })
          | to_entries
          | map(.value)
          | map(select((.label | type) == "string"))
          | map(.label = (.label | gsub("^\\s+|\\s+$"; "")))
          | map(select((.label | test("[A-Za-z0-9]")) and (.label != "Unlabeled component")))
          | map(select(.add != 0 or .change != 0 or .destroy != 0))
          | sort_by([-(.destroy), -(.change), -(.add), .label])
        )
    }
' "$summary_path")"

total_add="$(jq -r '.total.add // 0' <<<"$rows_json")"
total_change="$(jq -r '.total.change // 0' <<<"$rows_json")"
total_destroy="$(jq -r '.total.destroy // 0' <<<"$rows_json")"
breakdown_count="$(jq -r '.rows | length' <<<"$rows_json")"

{
  echo "### Terraform Plan"
  echo
  echo "| Module / Service | Add | Change | Destroy |"
  echo "| --- | --- | --- | --- |"
  echo "| **Total** | $total_add | $total_change | $total_destroy |"
  if [[ "$breakdown_count" -gt 0 ]]; then
    jq -r '.rows[] | "| `\(.label | gsub("\\|"; "\\\\|"))` | \(.add) | \(.change) | \(.destroy) |"' <<<"$rows_json"
  fi
  echo
} > "$markdown_path"

write_output "has_plan_markdown" "true"
if [[ "$breakdown_count" -gt 0 ]]; then
  write_output "has_plan_breakdown" "true"
else
  write_output "has_plan_breakdown" "false"
fi
write_output "plan_breakdown_count" "$breakdown_count"
write_output "total_add" "$total_add"
write_output "total_change" "$total_change"
write_output "total_destroy" "$total_destroy"
