# Architecture Documentation

This is an item-bank API, not an exam-taking platform.

## Assumptions

This API is:

1. Purely for exam items' management not exam delivery (i.e. for a learner
   taking an exam)
   - Concerns to be intentionally ignored are:
     - User auth
     - Answer attempts
     - Grouping of items by exam
2. Only the most recent version of an Item are supported; older versions are
   kept for audit logs
3. System auth can be achieved via infrastructure such that direct access to
   this API is structurally impossible; only access through specific exposed
   services is possible

## Data Model

- `PK = id` - an item's UUID
- `SK = <value>`
  - `CURRENT` (sentinel value) - for the _active_ (live) record
  - `<zero-padded-number>` - for historical records
- GSIs - only projecting using `CURRENT`
  - `subject-index` - pull items within a specific subject only

_* The sentinel value is to enable faster data reads while also keeping the full
history in a single table for atomicity. New versions require two writes instead
of only one, but writes will be far less frequent than reads so the tradeoff is
worth it._

## Infra

No special reason for choosing Terraform over CDK.

The handler functions (TypeScript) were restructured to accept the API Gateway
proxy event objects directly in order to take advantage of the API Gateway
parsing: routes and parameters.
