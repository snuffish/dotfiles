---
name: backend-signalr
description: "[Project: GR.PRIIS.Backend] Backend SignalR hub for GR.PRIIS.Backend — AccountHub at /realtime/account, IAccountClient.ReceiveUnreadCount, AccountConnectionStore, AccountRealtimeBroadcastService polling, configuration. Load when modifying real-time push behavior or the AccountHub. Load ONLY when working on the GR.PRIIS.Backend project or in the GR repository."
---

# SignalR Real-Time — Backend

Real-time notification counts are pushed to connected browser clients via SignalR. The hub is **read-only from the agent perspective** — do not bypass `NotificationDispatcher` to push custom messages.

---

## Hub: `AccountHub`

- **URL:** `/realtime/account` (mapped in `Program.cs`, must not change — frontend hardcodes this path)
- **Authentication:** required; only authenticated users can connect
- **On connect:** registers connection in `AccountConnectionStore` and immediately pushes the current unread count
- **On disconnect:** removes from `AccountConnectionStore`

**Client interface** (`IAccountClient`):
```csharp
public interface IAccountClient
{
    Task ReceiveUnreadCount(int count, DateTimeOffset? latestCreatedAtUtc);
}
```

---

## Connection Store

`AccountConnectionStore` is a thread-safe `ConcurrentDictionary<Guid, ConcurrentDictionary<string, byte>>` — keyed by `UserId`, inner key is `ConnectionId`. Supports multiple concurrent connections per user (multiple browser tabs).

---

## Broadcast Service

`AccountRealtimeBroadcastService` is a background service that polls on a configurable interval:

```json
// appsettings.json
{
  "AccountRealtime": {
    "BroadcastInterval": "00:01:00"
  }
}
```

**Behavior:**
1. Queries all currently connected user IDs from `AccountConnectionStore`
2. Runs a single batched DB query for unread counts
3. Compares against a local in-memory cache
4. Only calls `ReceiveUnreadCount` on the hub when the count or `latestCreatedAtUtc` has changed
5. This avoids unnecessary SignalR traffic when nothing has changed

**The push is eventual** — up to the broadcast interval. Never rely on it being instant.

---

## How Notifications Trigger a Push

The notification pipeline (see `.claude/skills/notifications/SKILL.md`) writes `UserInAppNotification` entities via `NotificationDispatcher`. After the batch is saved, the broadcast service picks up the change within its polling interval and pushes the updated count.

There is no direct call from notification handlers to the hub — the broadcaster polls independently.

---

## Rules for Agents

```
❌ Do not change the hub URL /realtime/account — frontend hardcodes this path
❌ Do not push custom messages through AccountHub directly — only ReceiveUnreadCount is supported
❌ Do not write UserInAppNotification directly to bypass the dispatcher
❌ Do not add new hub methods without coordinating with the frontend team
✅ To trigger a faster update, adjust BroadcastInterval in appsettings.json (dev/test only)
✅ For optimistic UI decrement (mark-as-read), the frontend dispatches decrementUnreadCount() locally
```
