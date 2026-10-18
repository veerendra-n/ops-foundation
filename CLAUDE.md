# Working in ops-foundation

- Runbooks follow docs/runbook-contract.md. Keep all judgement in `tasks/decide.yml` and add a case to
  `tests/cases.yml` for every outcome; `tools/validate_repo.py` enforces it.
- Never commit secrets or real customer data. `customers/lab` is fictitious; real customers get their own folder.
- Before pushing: `python -m pytest`, `yamllint -s .`, `ansible-lint`, `ruff check tools integrations tests`.
- Parameter defaults must match between `meta.yml` and `runbook.yml`.
