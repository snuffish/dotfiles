---
name: backend-notifications
description: "[Project: GR.PRIIS.Backend] Backend notification pipeline for GR.PRIIS.Backend — IBusinessEvent, TickerQ job scheduling, NotificationDispatcher, INotificationHandler, INotificationDefinition, in-app channel, and SignalR push. Load when implementing new notifications or modifying the notification system. Load ONLY when working on the GR.PRIIS.Backend project or in the GR repository."
---

# Notification and Event System

The notification system uses a two-layer pattern. **Business events schedule background jobs; jobs dispatch notifications through multiple channels.**

---

## Layer 1 — Business Events

Implement `IBusinessEvent<TEventData>` in Library. When a domain action completes, call `PublishAsync(data, ct)`. The event schedules a TickerQ job with 3 retries (30 s / 120 s / 300 s).

```csharp
// Naming: describe the thing that happened
public sealed class FeedbackTicketCreatedEvent(IEventJobScheduler scheduler)
    : IBusinessEvent<FeedbackTicketCreatedEventData>
{
    public Task PublishAsync(FeedbackTicketCreatedEventData data, CancellationToken ct)
        => scheduler.ScheduleEventProcessingAsync(
               nameof(ProcessFeedbackTicketCreatedEventJob),
               data,
               $"FeedbackTicket {data.FeedbackTicketId} created",
               ct);
}

// Event data — a sealed record carrying the IDs needed by the handler
public sealed record FeedbackTicketCreatedEventData(Guid FeedbackTicketId, Guid CreatedByUserId);
```

All `IBusinessEvent<>` implementations are **auto-discovered by Scrutor** — no manual registration.

---

## Layer 2 — Notification Handlers

Handlers are TickerQ jobs that use `NotificationDispatcher.SendNotificationAsync`:

```csharp
[TickerFunction(nameof(ProcessFeedbackTicketCreatedEventJob))]
public sealed class ProcessFeedbackTicketCreatedEventJob(NotificationDispatcher dispatcher)
{
    public async Task ProcessAsync(FeedbackTicketCreatedEventData data, CancellationToken ct)
        => await dispatcher.SendNotificationAsync(
               new FeedbackTicketCreatedNotificationSender(),
               data,
               ct);
}
```

The dispatcher orchestrates 4 steps:
1. `handler.GetRecipientUsersQuery(data)` — EF Core query returning target users
2. Load per-user preferences (`IUserNotificationPreferenceStore`)
3. `handler.GenerateContentAsync(data, recipients, ct)` — personalised content per recipient
4. Send via enabled channels: **email** (`IEmailClient`), **SMS** (`ISmsEnqueuer`), **in-app** (persists `UserInAppNotification`), **SignalR push** (via `AccountHub` after in-app save)

---

## Implementing a New Notification

**Step 1 — Define** a `sealed record` implementing `INotificationDefinition`:

```csharp
public sealed record FeedbackTicketCreatedNotification : INotificationDefinition
{
    public string Id => "feedback_ticket_created";
    public string DisplayName => "Synpunktsärende skapat";
    public NotificationGroup Group => NotificationGroup.Feedback;
    public IReadOnlyList<RoleType> ForRoles => [RoleType.FeedbackHandler, RoleType.PlacementManager];
    public bool DefaultEmailEnabled => true;
    public bool DefaultSmsEnabled => false;
    public bool DefaultInAppEnabled => true;
}
```

**Step 2 — Create** a handler implementing `INotificationHandler<TData>`. Name it after what it does, not the pattern:

```csharp
// ✅ FeedbackTicketCreatedNotificationSender
// ❌ FeedbackTicketNotificationHandler
public sealed class FeedbackTicketCreatedNotificationSender
    : INotificationHandler<FeedbackTicketCreatedEventData>
{
    public IQueryable<PriisUser> GetRecipientUsersQuery(
        FeedbackTicketCreatedEventData data,
        PriisDbContext dbContext)
        => dbContext.Users
            .Where(u => u.Roles.OfType<FeedbackHandlerRole>().Any());

    public async Task<NotificationContent[]> GenerateContentAsync(
        FeedbackTicketCreatedEventData data,
        IReadOnlyList<PriisUser> recipients,
        CancellationToken ct)
    {
        // return personalised content for each recipient
        return recipients.Select(r => new NotificationContent(
            UserId: r.Id,
            Subject: "Nytt synpunktsärende",
            Body: $"Hej {r.FirstName}, ett nytt ärende har skapats."
        )).ToArray();
    }
}
```

**Step 3 — Wire** the handler into the TickerQ job's processing method (see Layer 2 above).

**Step 4** — Handlers and definitions are **auto-discovered by Scrutor** — no manual registration needed.

**Step 5 — Register sample content** in `GetNotificationDefinitionsEndpoint` (`GR.PRIIS.API/Features/Reports/`). Add the handler as a constructor parameter, fetch a sample entity from the DB, and call `TryGenerateAndAddAsync` with representative data. This populates the notification preview in the admin UI.

---

## In-App Channel and SignalR Relationship

In-app notifications are persisted as `UserInAppNotification` entities by the dispatcher. After a batch is saved, `AccountRealtimeBroadcastService` polls on its configured interval (default 1 minute) and pushes the updated unread count to connected browser clients via SignalR `AccountHub`.

**Rule:** Never write `UserInAppNotification` entities directly — always go through `NotificationDispatcher`. The dispatcher handles preference checks, channel routing, and content generation.

The SignalR push is **eventual** (up to the broadcast interval). Clients must not rely on it being instantaneous. See `.claude/skills/signalr/SKILL.md` for the hub details.

---

## Anti-Patterns

```
❌ Writing UserInAppNotification directly to the DB — use NotificationDispatcher
❌ Calling notification handlers directly — they must be called via the dispatcher
❌ Naming handlers FooNotificationHandler — name by behaviour: FooCreatedNotificationSender
❌ Forgetting to register sample content in GetNotificationDefinitionsEndpoint
❌ Making INotificationDefinition a class — it must be a sealed record
❌ Throwing inside GenerateContentAsync — return empty content instead for users with missing data
```
