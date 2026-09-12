# AI Workflow

## Which tool(s) and why

I used **Claude Code** as my primary AI-assisted development and investigation tool throughout the assessment. I also used **ChatGPT** for some additional verification and to clarify my understanding of specific technical concepts and behaviors.

I mainly used AI as a **guidance and verification tool** rather than as an autonomous solution generator. It helped me understand unfamiliar parts of the repository, formulate investigation strategies, validate my reasoning, and explain SQL and pipeline behavior.

I also used Claude Code to help create some of the **additional test files** once I had established the underlying logic and expected behavior.

I independently verified AI suggestions against the repository, source data, revenue policy, SQL results, Git state, and test results before making technical decisions.

## 1. Concrete prompts and what came back

### Prompt 1 — Project analysis and workflow

> "Perform a comprehensive analysis of the entire project to help me understand its objectives, requirements, structure, and expected outcomes. I want to understand what the assessment is asking me to accomplish, how the different project components relate to each other, and what the main areas of investigation should be. Based on this analysis, help me establish a structured workflow for approaching the assessment, including how I should explore the repository, understand the data and revenue policy, analyze the existing pipeline, identify potential defects, validate findings, implement fixes, and verify the final results."

**What came back:**
Claude Code helped me understand the overall project structure, assessment requirements, and the relationship between the different components. I used this as a starting point for my own investigation rather than treating the analysis as the source of truth.

### Prompt 2 — Pipeline architecture, efficiency, and scalability

> "I want you to analyze the current data pipeline from an engineering perspective. First, help me understand the grain and purpose of each model, how data flows between the different pipeline stages, and where transformations and aggregations occur. Then identify potential structural weaknesses, unnecessary processing, inefficient joins or aggregations, and any other areas that could become problematic as the data volume grows significantly."

**What came back:**
The response helped me identify areas related to model grain, joins, aggregations, repeated processing, maintainability, and scalability. I used these suggestions to guide my review of the pipeline and decided myself which improvements were relevant within the assessment scope.

### Prompt 3 — Revenue logic

> "Help me reason through this revenue issue using the revenue policy as the source of truth. I want to understand the business rule first, then trace how the current SQL implements that rule. Identify where the implementation differs from the policy and show me how to prove the difference using the actual data."

**What came back:**
Claude Code helped me structure the investigation around the revenue policy, data grain, dates, joins, filters, and aggregation logic. I then validated the hypothesis using the actual source data and SQL queries before implementing the fix.

### Prompt 4 — Test coverage and strategy

> "Based on the project requirements, revenue policy, existing pipeline, and the defects we have identified, help me determine what additional test cases would provide the most valuable coverage. I want you to suggest potential test files or test scenarios that are aligned with the business rules and the types of defects that could occur in this pipeline."

**What came back:**
The response suggested test scenarios based on the business rules and discovered defects. I reviewed those suggestions and used Claude Code to help create some of the additional test files after determining which cases were actually relevant.

## 2. One moment where the AI was confidently wrong

During the repository/checksum troubleshooting, Claude Code suggested:

```bash
git rm --cached -r data/*.csv
```

I executed the command before noticing the correction in the same exchange. As a result, `git status` showed the nine CSV files as deleted/staged.

This immediately showed that the command had modified the Git index in an unintended way. I used the actual Git state to diagnose the problem and recovered the files from `HEAD` without modifying the source data.

I encountered another incorrect AI assumption when implementing the platform-fee date filter. The AI initially assumed that an open-ended `effective_to` value was stored as SQL `NULL`, but the actual CSV contained an empty string (`''`).

I caught this by checking the actual source data instead of relying on the AI's assumption.

These cases reinforced my approach of treating AI suggestions as hypotheses that must be verified against the actual repository, data, business rules, and test results.

## 3. Parallel agents, subagents, or worktrees

I did **not** use parallel agents, subagents, or worktrees.

I worked through the assessment as a single controlled workflow, investigating one issue at a time and validating the results before moving on.

This was intentional because the main challenge was understanding the relationship between the pipeline, source data, business policy, and revenue calculations.
