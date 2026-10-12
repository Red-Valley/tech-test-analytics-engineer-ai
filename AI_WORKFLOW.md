# AI Workflow

## Tools Used

- Microsoft Copilot

## Why I Used AI

I used AI as a technical assistant to accelerate repository exploration, SQL analysis, debugging, and documentation.

AI was not used to blindly generate solutions.

All findings were validated through:

- Source documentation
- SQL queries
- Test results
- Manual inspection of data

## Representative Prompts

### Prompt 1

Review the repository structure and explain the role of each folder and file before making any modifications.

**Outcome**

Helped establish an investigation strategy and understand repository organization.

### Prompt 2

Compare the revenue policy against the SQL models and identify potential areas where implementation may not match business rules.

**Outcome**

Generated hypotheses around:

- FX conversion
- Refund handling
- Platform fees

These hypotheses were later validated manually.

### Prompt 3

Help investigate why revenue records contain null monetary values and suggest validation queries.

**Outcome**

Led to identifying the FX date matching issue.

### Prompt 4

Analyze failed tests and connect them to likely data model problems.

**Outcome**

Helped trace test failures back to:

- duplicated orders
- pending orders
- null monetary values

### Prompt 5

Help quantify the impact of identified defects and document them for findings.

**Outcome**

Used to structure findings and organize evidence.

## Example Where AI Was Wrong

Initially, AI suggested that open-ended platform fee validity periods were stored as NULL values.

After manually inspecting the source data, I confirmed they were represented by empty strings ('').

This caused fee calculations to remain null for a large number of rows.

The issue was corrected after validating the actual source data.

This reinforced the importance of validating AI output against real data.

## Validation Process

Every AI suggestion was validated through:

- SQL analysis
- Business documentation review
- Manual data inspection
- Test execution

No change was accepted solely because it was suggested by AI.

## Results

- Tests improved from 4/7 passing to 7/7 passing.
- Major business defects were corrected.
- FY2026 Q2 revenue changed from:

727,922.09 USD

to

382,929.62 USD.
``
