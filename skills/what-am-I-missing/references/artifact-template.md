# Blind-Spot Artifact Template (`<prefix>-what_am_i_missing-<suffix>.md`)

Used by `/what-am-I-missing deep`, `/implement-feature` Phase 2b, and `/investigate` §8 (embedded under `## 8. Blind Spots & Critical Omission Analysis (What Am I Missing?)`).

```markdown
<!-- artifact-owner: … -->

# 🎯 The #1 Most Important Thing You Are Missing

> **[One bold, unambiguous sentence identifying the primary blind spot]**

[Direct technical explanation: What is the unstated assumption or hidden invariant, why does it exist, and why is it easy to overlook?]

---

## 💥 The Blast Radius / Failure Scenario

- **Trigger:** [The exact condition, user action, edge case, or production event that triggers the failure]
- **Impact:** [The precise exception, data corruption, security vulnerability, or performance cliff that occurs]
- **Why it went unnoticed:** [Why existing tests, mocks, or local development didn't catch it]

---

## 🔍 Secondary Blind Spots & Nuances

1. **[Secondary Risk 1]:** [Concise explanation of related implication]
2. **[Secondary Risk 2]:** [Concise explanation of related implication]

---

## 🛠️ Actionable Recommendation

1. **Immediate Fix:** [Concrete step to eliminate the #1 blind spot]
2. **Structural Prevention:** [How to make this impossible to get wrong in the future via types, architecture, or automated tests]

---

## 📄 Relevant References

- 📄 [Active Plan / Relevant File](path/to/relevant/file.ts#L10)
```
