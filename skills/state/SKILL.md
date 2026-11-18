---
name: state
description: Manually-invoked skill that recaps what the current thread is doing and how far along it is. Use when the user says "state", "where are we", or "what % are we done".
disable-model-invocation: true
---

in plain english remind me what we're doing in this thread, how far along we are, and what's next. answer in exactly this shape:

```
Doing: …
Step: N of M, <current phase/step> → last: <final phase/step>
Done: ~N%
Status: on track / blocked on X / waiting on you for X
ETA: …
Next: …
```

- Step: name the plan phase or to-do item in progress, its number out of the total, and the last one we're heading for. with no plan or list, write "no plan".
- Done: count finished plan phases or to-do items against the total. with no plan or list, write "no plan" instead of a number.
- ETA: base it on the work left, e.g. "2 phases left, ~1 session each". write "unknown" when you can't tell. never give a clock time.
- Status: if the next step needs me (an approval, a run i have to do, a review), say so here.

be extremely concise.
