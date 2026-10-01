---
name: deploy-staging
description: >-
  Deploy the current branch to staging. Use when asked to deploy. Triggered by: deploy, staging.
license: Apache-2.0
compatibility: Needs git and docker.
metadata:
  version: "1.2.0"
  owner: platform
allowed-tools: Bash(git *) Read
when_to_use: When a change is ready to try on staging.
argument-hint: "[environment]"
arguments: [environment]
disable-model-invocation: true
user-invocable: "yes"
disallowed-tools: [WebFetch]
model: inherit
effort: high
context: fork
agent: Explore
background: false
hooks: {}
paths: ["apps/**", "infra/**"]
shell: bash
---

# Deploy to staging
