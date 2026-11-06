# Module 3. Alerts and autoscale (25 min)

[← Module 2](02-monitoring.md) | [Next: Module 4 →](04-cost.md)

## Goals

- Create an **alert rule + action group** that notifies a person when something goes wrong.
- Create **autoscale** that changes the instance count with load.
- Generate load and watch **scale-out and the alert happen together**.

## Key concepts

| Component | Role |
|---|---|
| Metric alert rule | Evaluates a condition such as "average CPU above 70% for 5 minutes" every minute |
| Action group | **Who** gets notified and **how** when an alert fires (email, SMS, webhook, ...) |
| Autoscale | Adds or removes instances within a min-max range based on conditions |

The alert **tells a human**; autoscale **lets the system respond by itself**. They watch the same CPU metric but do different jobs.

## Step 1. Create the action group (email) (3 min)

```bash
source .lab.env
export EMAIL="me@example.com"      # use an address you can read

az monitor action-group create -g $RG -n ag-halab --short-name halab \
  --action email ops-admin "$EMAIL" -o none
```

You may get a confirmation email from `Azure Monitor`. Portal: Monitor → Alerts → **Action groups**.

## Step 2. Create the CPU alert rule (5 min)

```bash
VMSS_ID=$(az vmss show -g $RG -n $VMSS --query id -o tsv)
AG_ID=$(az monitor action-group show -g $RG -n ag-halab --query id -o tsv)

az monitor metrics alert create -g $RG -n alert-halab-cpu-high \
  --scopes $VMSS_ID \
  --condition "avg Percentage CPU > 70" \
  --window-size 5m --evaluation-frequency 1m \
  --severity 2 \
  --action $AG_ID \
  --description "VMSS average CPU above 70% for 5 minutes" -o none
```

| Option | Meaning |
|---|---|
| `--condition` | Average CPU above 70% |
| `--window-size 5m` | Look at the last 5 minutes of data |
| `--evaluation-frequency 1m` | Evaluate every minute |
| `--severity 2` | Severity (0 critical ~ 4 informational) |

Portal: Monitor → Alerts → **Alert rules**, find `alert-halab-cpu-high`.

## Step 3. Create the autoscale rules (7 min)

```bash
# min 2, max 4, default 2
az monitor autoscale create -g $RG -n autoscale-halab \
  --resource $VMSS --resource-type Microsoft.Compute/virtualMachineScaleSets \
  --min-count 2 --max-count 4 --count 2 -o none

# Scale out: add 1 when 3-minute average CPU > 70%
az monitor autoscale rule create -g $RG --autoscale-name autoscale-halab \
  --condition "Percentage CPU > 70 avg 3m" --scale out 1 --cooldown 3 -o none

# Scale in: remove 1 when 5-minute average CPU < 30%
az monitor autoscale rule create -g $RG --autoscale-name autoscale-halab \
  --condition "Percentage CPU < 30 avg 5m" --scale in 1 --cooldown 5 -o none

# Send an email when scaling happens
az monitor autoscale update -g $RG -n autoscale-halab --add-action email "$EMAIL" -o none
```

> **Design tip**: keep a **wide gap** between the scale-out threshold (70%) and the scale-in threshold (30%). A narrow gap causes flapping (scale out, scale in, repeat). The cooldown is how long to wait after one adjustment before the next.

Portal: Monitor → **Autoscale** → `$VMSS` shows the 2 rules.

## Step 4. Generate load (2 min)

```bash
scripts/stress.sh start 900
```

The `stress` tool drives CPU on every instance close to 100% for 15 minutes. (It uses `az vmss run-command`, so no SSH is needed.)

## Step 5. Watch scale-out and the alert (8 min)

Starting 1-2 minutes in, repeat the checks below.

**① Instance count**

```bash
az vmss list-instances -g $RG -n $VMSS --query "[].{id:instanceId, name:osProfile.computerName, state:provisioningState}" -o table
```

About 3 minutes after CPU passes 70%, you get **3 instances**. (The new instance has no load, so the average may fall below 70% and scaling stops at 3. This is normal.)

**② Is the new instance serving traffic?**

```bash
scripts/curl-loop.sh 30      # once the new instance finishes booting (3-5 min) you see 3 names
```

**③ In the portal**

- Monitor → Autoscale → `autoscale-halab` → **Run history**: the scale-out event
- Monitor → Alerts: `alert-halab-cpu-high` is **Fired**. Check your email too.
- In Log Analytics run Module 2's Q2 (CPU) and the query below (instance count).

```kusto
Heartbeat
| where TimeGenerated > ago(1h)
| summarize Instances = dcount(Computer) by bin(TimeGenerated, 1m)
| render timechart
```

**④ (Optional) Events from the command line**

```bash
az monitor activity-log list -g $RG --offset 1h \
  --query "[?contains(operationName.localizedValue, 'utoscale')].{time:eventTimestamp, op:operationName.localizedValue, status:status.localizedValue}" -o table
```

## Step 6. Stop the load

```bash
scripts/stress.sh stop
```

When CPU drops, the alert becomes **Resolved** and you get a resolved email. Autoscale scales in after CPU stays below 30% for 5+ minutes. If you do not want to wait, move on to Module 4 and Cleanup.

## Takeaways

```text
Load rises → CPU rises ─┬→ alert rule → action group → email to the operator   (a human knows)
                        └→ autoscale → add an instance                          (the system responds)
```

## Troubleshooting

| Symptom | Fix |
|---|---|
| CPU does not rise | Is `stress` running? `az vmss run-command invoke -g $RG -n $VMSS --instance-id 0 --command-id RunShellScript --scripts "systemctl status lab-stress --no-pager"` |
| No scale-out | Metric delay plus the 3-minute average plus evaluation time. Wait 5-10 minutes |
| `QuotaExceeded` on scale-out | Not enough vCPU quota. Check the run history error and lower the max count |
| No alert email | Check spam; use **Test** on the action group to verify delivery |

Next → [Module 4. Cost](04-cost.md)
