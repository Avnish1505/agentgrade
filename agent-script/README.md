# Agent Script

The deterministic gate lives here. This is the part of the project that makes it more than a demo.

Agent Script is GA as of Spring '26 and is TypeScript based. Get the current syntax from the official Agent Script Developer Guide and the open source repository rather than from memory; the language is new and examples age fast.

## What belongs in this folder

- The subagent definitions
- The refund gate: policy cap, return window, ownership check
- The escalation path

## The rule to hold to

Anything that is a comparison, a date calculation, or an authorisation check is written as deterministic logic. Anything that is wording, summarising, or intent classification goes to the model. If you find yourself writing a prompt that says "make sure you never...", that is a sign the rule belongs in code instead.

Hinglish: Jo cheez number ya date ya permission se decide hoti hai, woh code mein. Jo language se decide hoti hai, woh model ke paas.

## Files

TODO: list each file and what it does, once written.
