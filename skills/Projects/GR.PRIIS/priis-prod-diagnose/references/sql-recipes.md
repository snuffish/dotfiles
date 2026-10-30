# SQL recipes for production rounds

Building blocks for a round script. Copy the ones the hypothesis needs, swap the inputs, keep the house rules. Every block ran in production SSMS on 2026-10-30 (round 1 of the 1482-010280 / 1482-010425 diagnosis) and against the local database (`priis-local-stack` `db.py`); re-check names with `lookup.py table` when a block fails.

## House rules

| Rule                                                                                                                                           | Why                                                                                                                                                                                         |
| ---------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Strictly read-only: standalone `SELECT` statements only. No `DECLARE`, `INSERT`, table variables, `#temp`, `SELECT … INTO`, `EXEC`, DML or DDL | The skill never generates a mutation, not even into a table variable                                                                                                                        |
| Paste-safe: ASCII only, no comments, no CTEs, lines of 100 characters or fewer                                                                 | A script with Swedish characters, `--` comments, CTEs and 138-character lines ran locally but failed in production SSMS with Msg 102 after the trip through the terminal and remote desktop |
| Every statement repeats the ticket filter as a derived table `x`                                                                               | Each statement then runs on its own; when one fails the user selects another and presses F5                                                                                                 |
| ASCII labels: English enum names, and `LIKE '%rende avslutat%'` instead of `Matchningsärende`                                                  | Keeps the paste-safe rule when matching Swedish subjects                                                                                                                                    |
| First column of every result set is a label: `'2 Ticket' AS ResultSet`                                                                         | Results come back stacked in one text dump                                                                                                                                                  |
| At most about six columns; `LEFT(Subject, 60)` for long text                                                                                   | Results to Text pads every `nvarchar` column to its full width                                                                                                                              |
| Decode every enum int with `lookup.py enum <Enum> --case <col>`, then swap the Swedish labels for the enum names                               | `Status 99` and `ClosedReason 4` needed decoding by hand otherwise                                                                                                                          |
| `STRING_AGG(CAST(x AS nvarchar(max)), ', ')` over a `SELECT DISTINCT`                                                                          | `STRING_AGG` over `nvarchar(n)` fails with Msg 9829 past 8000 bytes; one row per administration role repeats names                                                                          |
| Times are UTC (`CreatedOn`, `SentOnUtc`, `ChangedOnUTC`, `PeriodStart`); cron strings are UTC too                                              | Swedish time is UTC+1/+2; the minute tells which job ran (`:00` vs `:15`)                                                                                                                   |
| Temporal tables: `FROM <table> FOR SYSTEM_TIME ALL AS h` for history                                                                           | `lookup.py table` flags them as `temporal`                                                                                                                                                  |
| Never select `PasswordHash`, `SecurityStamp`, `PhoneNumber`, `HtmlBody`, personnummer or free-text notes                                       | Personal data leaves production through the pasted results                                                                                                                                  |

## Input: tickets by their UI number

The UI number is `<municipality code>-<IncrementalNumber, 6 digits>`, as the notification handlers build it (`MatchingTicketAutoClosureNotificationHandler.cs:123`). Every statement below opens its `FROM` with this derived table; swap `'1482'` and the numbers in each one.

```sql
FROM (SELECT t.Id, CONCAT(m.Code, '-', RIGHT(CONCAT('000000', t.IncrementalNumber), 6))
             AS TicketNumber
      FROM Matching.MatchingTickets t
      JOIN Register.Administrations a ON a.Id = t.AdministrationId
      JOIN Register.Municipalities m ON m.Id = a.MunicipalityId
      WHERE m.Code = '1482' AND t.IncrementalNumber IN (10280, 10425)) x
```

## People on a ticket, with roles in the ticket's administration

Primary handler, backup handlers (`Matching.BackupHandlerForMatchingTicket`) and placement handler. Role rows are TPH in `Auth.AspNetUserRoles`; administration roles carry `AdministrationId`, the column the recipient queries filter on (`MatchingSuggestionInactivityReminderNotificationHandler.cs:68-75`).

```sql
SELECT '1 People' AS ResultSet, x.TicketNumber, tp.TicketRole, u.Email,
       (SELECT STRING_AGG(CAST(rn.Name AS nvarchar(max)), ', ')
        FROM (SELECT DISTINCT r.Name
              FROM Auth.AspNetUserRoles ur
              JOIN Auth.AspNetRoles r ON r.Id = ur.RoleId
              WHERE ur.UserId = u.Id
                AND (ur.AdministrationId IS NULL
                     OR ur.AdministrationId = x.AdministrationId)) rn) AS Roles,
       IIF(u.EmailConfirmed = 1, 'yes', 'NO') AS EmailConfirmed
FROM (SELECT t.Id, t.AdministrationId, t.PrimaryHandlerId, t.PlacementHandlerId,
             CONCAT(m.Code, '-', RIGHT(CONCAT('000000', t.IncrementalNumber), 6)) AS TicketNumber
      FROM Matching.MatchingTickets t
      JOIN Register.Administrations a ON a.Id = t.AdministrationId
      JOIN Register.Municipalities m ON m.Id = a.MunicipalityId
      WHERE m.Code = '1482' AND t.IncrementalNumber IN (10280, 10425)) x
CROSS APPLY (SELECT x.PrimaryHandlerId AS UserId, 'Primary' AS TicketRole
             UNION ALL
             SELECT b.BackupHandlerId, 'Backup'
             FROM Matching.BackupHandlerForMatchingTicket b
             WHERE b.MatchingTicketId = x.Id
             UNION ALL
             SELECT x.PlacementHandlerId, 'PlacementHandler'
             WHERE x.PlacementHandlerId IS NOT NULL) tp
JOIN Auth.AspNetUsers u ON u.Id = tp.UserId
ORDER BY x.TicketNumber, tp.TicketRole;
```

`EmailConfirmed` matters: the dispatcher sends email only when it is set (`NotificationDispatcher.cs:163`). `Roles` NULL means the person holds no role in the ticket's administration, which is a finding in itself: a recipient query that filters on the administration skips them.

## Ticket state, decoded

```sql
SELECT '2 Ticket' AS ResultSet, x.TicketNumber,
       CASE t.Status WHEN 10 THEN 'AwaitingAllocation' WHEN 30 THEN 'Assigned'
                     WHEN 40 THEN 'MatchingInProgress' WHEN 50 THEN 'MatchingResultExists'
                     WHEN 60 THEN 'MatchingSuggestionExists' WHEN 70 THEN 'SupplierSelected'
                     WHEN 90 THEN 'Completed' WHEN 99 THEN 'Canceled'
                     ELSE CONCAT('?', t.Status) END AS Status,
       CASE t.ClosedReason WHEN 0 THEN 'NoLongerNeeded' WHEN 1 THEN 'ResolvedOtherwise'
                           WHEN 2 THEN 'ReplacedByNewCase' WHEN 3 THEN 'CreatedInError'
                           WHEN 4 THEN 'AUTO_INACTIVITY' WHEN 5 THEN 'Unresolved'
                           ELSE CAST(t.ClosedReason AS varchar(10)) END AS ClosedReason,
       IIF(t.PlacementHandlerId IS NULL, 'NONE', 'set') AS PlacementHandler,
       t.ChangedOnUTC
FROM (SELECT t.Id, CONCAT(m.Code, '-', RIGHT(CONCAT('000000', t.IncrementalNumber), 6))
             AS TicketNumber
      FROM Matching.MatchingTickets t
      JOIN Register.Administrations a ON a.Id = t.AdministrationId
      JOIN Register.Municipalities m ON m.Id = a.MunicipalityId
      WHERE m.Code = '1482' AND t.IncrementalNumber IN (10280, 10425)) x
JOIN Matching.MatchingTickets t ON t.Id = x.Id;
```

Regenerate the `CASE` lists with `lookup.py enum MatchingTicketStatus --case t.Status` rather than trusting this copy.

## Status history (temporal)

`ChangedByPlacementHandler` tells a placement handler's own action (e.g. selecting the contract, which excludes them from `matching_ticket_closed_by_handler`) from someone else's.

```sql
SELECT '3 History' AS ResultSet, x.TicketNumber, h.Status,
       IIF(h.PlacementHandlerId IS NULL, 'NONE', 'set') AS PlacementHandler,
       IIF(h.ChangedBy = h.PlacementHandlerId, 'yes', 'no') AS ChangedByPlacementHandler,
       h.PeriodStart
FROM (SELECT t.Id, CONCAT(m.Code, '-', RIGHT(CONCAT('000000', t.IncrementalNumber), 6))
             AS TicketNumber
      FROM Matching.MatchingTickets t
      JOIN Register.Administrations a ON a.Id = t.AdministrationId
      JOIN Register.Municipalities m ON m.Id = a.MunicipalityId
      WHERE m.Code = '1482' AND t.IncrementalNumber IN (10280, 10425)) x
JOIN Matching.MatchingTickets FOR SYSTEM_TIME ALL AS h ON h.Id = x.Id
ORDER BY x.TicketNumber, h.PeriodStart;
```

## Inactivity reminders logged

`NotificationDefinitionId` says which job wrote the row; `ReminderType` 0 = first, 1 = second; `TicketStatus` is the status when it was sent. A second `First` row after new activity is a reset cycle, not a bug: only reminders sent after the latest activity count. The suggestion job's interval is `InactivitySuggestionReminderMinDays` (default 2, `MatchingTicketsOptions.cs:16`), not `InactivityClosureDays`.

```sql
SELECT '4 Reminders' AS ResultSet, x.TicketNumber, r.NotificationDefinitionId,
       IIF(r.ReminderType = 1, 'Second', 'First') AS ReminderType,
       r.TicketStatus, r.SentOnUtc
FROM (SELECT t.Id, CONCAT(m.Code, '-', RIGHT(CONCAT('000000', t.IncrementalNumber), 6))
             AS TicketNumber
      FROM Matching.MatchingTickets t
      JOIN Register.Administrations a ON a.Id = t.AdministrationId
      JOIN Register.Municipalities m ON m.Id = a.MunicipalityId
      WHERE m.Code = '1482' AND t.IncrementalNumber IN (10280, 10425)) x
JOIN Matching.MatchingTicketInactivityReminders r ON r.MatchingTicketId = x.Id
ORDER BY x.TicketNumber, r.SentOnUtc;
```

## Emails queued per recipient

`Communication.EmailQueue` holds every queued email with `Subject`, `ToEmail`, `UserId` and `Status` (0 Pending, 1 Sent, 2 Failed). `Sent` means the mail server accepted it, not that it reached the inbox. Narrow the subject filter to the notification under study with an ASCII fragment of its subject template (`lookup.py notification "<subject text>"` prints it).

```sql
SELECT '5 Emails' AS ResultSet, x.TicketNumber, e.CreatedOn, e.ToEmail,
       LEFT(e.Subject, 60) AS Subject,
       CASE e.Status WHEN 0 THEN 'Pending' WHEN 1 THEN 'Sent' WHEN 2 THEN 'Failed'
                     ELSE CONCAT('?', e.Status) END AS Status
FROM (SELECT t.Id, CONCAT(m.Code, '-', RIGHT(CONCAT('000000', t.IncrementalNumber), 6))
             AS TicketNumber
      FROM Matching.MatchingTickets t
      JOIN Register.Administrations a ON a.Id = t.AdministrationId
      JOIN Register.Municipalities m ON m.Id = a.MunicipalityId
      WHERE m.Code = '1482' AND t.IncrementalNumber IN (10280, 10425)) x
JOIN Communication.EmailQueue e ON e.Subject LIKE '%' + x.TicketNumber + '%'
WHERE e.Subject LIKE '%rende avslutat%' OR e.Subject LIKE '%rende avbrutet%'
ORDER BY x.TicketNumber, e.CreatedOn;
```

## In-app notifications per recipient

`ReadAtUtc` set means the recipient opened it in PRIIS: the strongest evidence that a notification reached them.

```sql
SELECT '6 InApp' AS ResultSet, x.TicketNumber, n.CreatedOn, u.Email,
       LEFT(n.Title, 60) AS Title, n.ReadAtUtc
FROM (SELECT t.Id, CONCAT(m.Code, '-', RIGHT(CONCAT('000000', t.IncrementalNumber), 6))
             AS TicketNumber
      FROM Matching.MatchingTickets t
      JOIN Register.Administrations a ON a.Id = t.AdministrationId
      JOIN Register.Municipalities m ON m.Id = a.MunicipalityId
      WHERE m.Code = '1482' AND t.IncrementalNumber IN (10280, 10425)) x
JOIN Notifications.UserInAppNotifications n
  ON n.Url LIKE '%' + CAST(x.Id AS varchar(36)) + '%'
JOIN Auth.AspNetUsers u ON u.Id = n.UserId
ORDER BY x.TicketNumber, n.CreatedOn;
```

## Notification settings for the people on the tickets

No row means the definition's defaults apply (`UserNotificationPreferenceStore.cs:101`).

```sql
SELECT '7 Settings' AS ResultSet, u.Email, p.NotificationId,
       p.InAppEnabled, p.EmailEnabled, p.SmsEnabled
FROM (SELECT t.PrimaryHandlerId AS UserId
      FROM Matching.MatchingTickets t
      JOIN Register.Administrations a ON a.Id = t.AdministrationId
      JOIN Register.Municipalities m ON m.Id = a.MunicipalityId
      WHERE m.Code = '1482' AND t.IncrementalNumber IN (10280, 10425)
      UNION
      SELECT b.BackupHandlerId
      FROM Matching.BackupHandlerForMatchingTicket b
      JOIN Matching.MatchingTickets t ON t.Id = b.MatchingTicketId
      JOIN Register.Administrations a ON a.Id = t.AdministrationId
      JOIN Register.Municipalities m ON m.Id = a.MunicipalityId
      WHERE m.Code = '1482' AND t.IncrementalNumber IN (10280, 10425)
      UNION
      SELECT t.PlacementHandlerId
      FROM Matching.MatchingTickets t
      JOIN Register.Administrations a ON a.Id = t.AdministrationId
      JOIN Register.Municipalities m ON m.Id = a.MunicipalityId
      WHERE m.Code = '1482' AND t.IncrementalNumber IN (10280, 10425)
        AND t.PlacementHandlerId IS NOT NULL) tp
JOIN Auth.AspNetUsers u ON u.Id = tp.UserId
JOIN Notifications.UserNotificationPreferences p ON p.UserId = u.Id
WHERE p.NotificationId IN ('matching_ticket_auto_closure',
                           'matching_suggestion_auto_closure',
                           'matching_ticket_closed_by_handler')
ORDER BY u.Email, p.NotificationId;
```
