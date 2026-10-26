`Legacy-7aff543.store` is a synthetic SwiftData store created with the stored model declarations and initializers from commit `7aff543`, before the date-only fields and release fixes. It contains invented data only: one move, household profile, institution, completed account with verification event, and an open custom task.

Regenerate on macOS with Xcode and the old commit available locally:

```sh
python3 scripts/generate_legacy_store_fixture.py
```

The generator extracts old declarations from git and runs them in a separate helper compiled with the production module name `movingsoon_app`; no old model declarations are linked into the app or tests. SQLite WAL pages are consolidated into the resource file. The fixture test copies the store to a temporary directory, opens it with the application's current schema, verifies retained records, backfills calendar dates in the explicit original timezone, saves, and reopens it.

This checks the previous schema migration. Physical-device installation over a signed previous app remains a separate release validation step.
