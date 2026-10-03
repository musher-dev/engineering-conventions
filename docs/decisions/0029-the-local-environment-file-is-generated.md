---
title: A developer's local .env is generated from the environment schema and never committed
date: 2026-10-03
status: accepted
deciders: ["@justinmerrell"]
supersedes: []
amends: ["0026"]
---

# 0029 — A developer's local .env is generated from the environment schema and never committed

## Context

[Decision 0026](0026-the-environment-contract-is-derived.md) derived two documents from `env.schema.yaml`: the
environment contract a consumer validates against, and a `.env.example` a developer copies to `.env`. ENVS-21 kept a
committed `.env.example` byte-for-byte equal to what the schema derives.

The example is a second copy of the schema in a weaker format. Every fact in it is already in `env.schema.yaml`,
where a reviewer reads it, so committing it adds a file to keep in step and a generated diff to every schema change.
It also stops one step short: a developer still copies it, fills in what each `local_generate` binding asks to mint,
and does it again by hand when the schema gains a variable.

## Decision

**A developer's local `.env` is generated from the schema by `conventions env-file`, and no environment file is
committed.**

- `conventions env-file SCHEMA` writes `.env` beside the schema, readable by its owner only: each `local_default`, each
  `local_generate` minted on that machine, each required variable empty, and every other variable commented out with
  its default, each under its description and facts.
- An existing `.env` is never replaced. The command lists the variables the schema declares that the file lacks, and
  fails when there are any; `--force` writes it again.
- ENVS-26 reports `.env` and every `.env.<suffix>` committed at the root or beside an environment schema.
- ENVS-27 reports a product schema whose `.env` git does not ignore.
- ENVS-21 is retired, with ENVS-26 and ENVS-27 as its successors, and `conventions env-contract --example` is
  removed. The contract and ENVS-20 are unchanged.

This amends decision 0026's list of derived documents; everything else in it stands.

## Consequences

### Positive

- The schema is the only committed description of the environment.
- A new developer runs one command and starts with a file that works, secrets included.
- A schema change no longer produces a generated diff in a second file.

### Negative

- A reader who looks for `.env.example`, by habit or with a tool that expects one, finds `env.schema.yaml` instead.
- `env-contract --example` is gone, which breaks a script that called it (`feat!`).
- ENVS-27 reads `.gitignore` patterns itself and covers the forms a repository writes for a `.env`, not every rule git
  applies.

### Neutral

- A product's `setup` task may run `conventions env-file`; nothing requires it.
- The dev environment's schema, `.devcontainer/env.schema.yaml`, is not held to ENVS-27.

## Enforcement

- ENVS-26 and ENVS-27 in `checks/rego/environment/env_files.rego`, with fixtures `envs-26-*` and `envs-27-*`, each
  with a near-miss.
- `tests/test_launcher.py` checks what `conventions env-file` writes, its file mode, the minted lengths, and that it
  never replaces a file without `--force`.

## Considered options

| Option | Summary | Outcome |
| --- | --- | --- |
| Keep the derived `.env.example` (ENVS-21) | Commit the example, checked for drift | rejected: a second copy of the schema that a developer still has to copy and complete |
| A fully commented-out `.env` | Generate every line commented | rejected: the developer uncomments the local values and mints secrets by hand, which the schema already says how to do |
| A ready-to-run, ignored `.env` | Generated on each machine, never committed | **chosen** |

## References

- [Decision 0026](0026-the-environment-contract-is-derived.md)
- [EC-0019 Environment contract](../../engineering-conventions/definitions/conventions/environment/env-contract.md)
