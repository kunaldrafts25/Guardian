# ADR 0004: Amazon Bedrock Advisory Role & Deterministic Safety Policy

## Status
Accepted (P0/P1/P2/P3 Invariant)

## Context
Large Language Models (LLMs) are probabilistic and subject to hallucinations, non-deterministic reasoning, prompt injection, and unpredictable latency. Emergency-response systems require deterministic, sub-second execution guarantees and cannot tolerate prompt injection that downgrades a panic alert or cancels an emergency dispatch.

## Decision
Confine Amazon Bedrock strictly to an **advisory and summarization role**. 
- Bedrock models (Claude 3 Haiku / Amazon Nova Micro) may summarize incident context and suggest helpful advice for first responders or users.
- Bedrock **CANNOT** authorize emergency actions, mint capability tokens, downgrade an alert, or modify incident state machines.
- All safety-critical actions (SMS dispatch, responder notification, radius expansion, capability minting) MUST be authorized by deterministic policy code in `aws/agent/policy.py`.

## Consequences
- **Positive**: Complete immunity from prompt injection attacks attempting to suppress emergency alerts.
- **Positive**: Predictable, deterministic latency and reproducible audit trails.
- **Negative**: AI responses cannot dynamically invent new autonomous dispatch tools without prior engineering and deterministic policy gating.
