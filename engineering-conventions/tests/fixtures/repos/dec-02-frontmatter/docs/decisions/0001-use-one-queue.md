---
title: Use one queue for background work
date: 2026-01-15
status: done
amends: ["0000"]
---

# 0001 — Use one queue for background work

## Context

Background work runs in three places.

## Decision

We run it from one queue.

## Consequences

One place to watch, and one place to fail.

## Enforcement

review-only: a reviewer rejects a second queue.
