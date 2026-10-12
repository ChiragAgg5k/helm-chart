## What

<!-- What does this change, and why? Link the issue it closes: "Closes #123". -->

## Testing

<!-- How you checked it beyond `make test`, e.g. `make kind-up install helm-test smoke` with the values you used. -->

## Checklist

- [ ] `make test` passes locally
- [ ] `make generate` was run and the generated files (`values.schema.json`, the chart `README.md`, the `artifacthub.io/images` annotation) are committed
- [ ] Unit tests added or updated
- [ ] Guides in `docs/` and files in `examples/` updated for changes to how the chart is configured
- [ ] An entry under `[Unreleased]` in `CHANGELOG.md` for user-facing changes (or the `skip-changelog` label). No `version` bump or `artifacthub.io/changes` edit: those happen when a release is cut, see `RELEASING.md`
- [ ] Renamed or removed values go through [Deprecating a value](https://github.com/appwrite/helm-chart/blob/main/CONTRIBUTING.md#deprecating-a-value)
