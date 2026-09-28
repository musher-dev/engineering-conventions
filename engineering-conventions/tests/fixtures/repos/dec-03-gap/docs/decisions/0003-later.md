---
title: Retry background work three times
date: 2026-02-01
status: accepted
---

# 0003 — Retry background work three times

## Context

Background work fails on transient errors.

## Decision

We retry it three times.

## Consequences

Transient failures no longer page anyone.

## Enforcement

review-only: a reviewer checks the retry count.
