# Module 4. Cost (5 min)

[← Module 3](03-alert-autoscale.md) | [Next: Cleanup →](05-cleanup.md)

## Goals

- Create a **budget** in Microsoft Cost Management and get notified before you overspend.
- Break down cost by **tag**.

> **Note**: cost data appears **8-24 hours** after usage, so resources you just created may not show yet. An empty view is normal; the goal is to learn the screens. Required permission: **Cost Management Contributor** (or Owner/Contributor) on the subscription or resource group.

## Step 1. Create a budget (3 min)

1. Azure portal → **Cost Management** → **Budgets** → **+ Add**
2. Scope: resource group `rg-ha-ops-lab` (limits just this lab, not the whole subscription)
3. Name: `budget-halab`, reset period: Monthly, amount: `10` (in your subscription's currency)
4. **Alert conditions**:
   | Type | % of budget | Email |
   |---|---|---|
   | Actual | 80% | your email |
   | Forecasted | 100% | your email |
5. **Create**

> A budget **does not stop spending.** It only notifies (or calls an action group) when a threshold is crossed. To stop resources automatically, connect the action group to something like Automation.

## Step 2. Cost analysis by tag (2 min)

In Module 0 every resource received the tags `project=azure-ha-ops-lab` and `env=workshop`.

1. **Cost Management** → **Cost analysis**
2. Scope: resource group `rg-ha-ops-lab`
3. **Group by** → **Tag** → `project`
4. Also group by **Resource type** to compare which service drives cost. (Expected: Virtual Machines largest, then Load Balancer, then Log Analytics)

If there is no data yet, raise the scope to the subscription and set the date range to the **last 7 days** to explore the layout.

## Think about it

- Without tags, how would you know whose cost this is? → Tagging policies by environment, team and project matter.
- The autoscale **maximum instance count** is also a cost ceiling.
- Log Analytics bills by **data volume (GB)**. That is why a DCR should collect only what you need.

Next → [Cleanup](05-cleanup.md)
