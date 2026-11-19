# claude-mem search and save

Read before searching or saving to claude-mem.

- Search in three steps: `search({query, project})` for an index, `timeline({anchor})` for context around the relevant results, then `get_observations({ids})` for only the records you chose. No auto or guided modes. `dumb_search({query, project})` is fast but shallow: use it for quick lookups only.
- Save with `save_memory({text, title, project})` for preferences, corrections, decisions and reusable lessons.
- Keep notes concise and separate verified facts from guesses. Never save credentials or material the user asked you not to remember.
- Use only the tools and argument names the active connection advertises. Search claude-mem directly when you need a result; never assume a search was intercepted.
