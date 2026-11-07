# Cleanup (5 min)

[← Module 4](04-cost.md) | [README](../../README.en.md)

The lab resources live in one resource group. `cleanup.sh` first explicitly deletes its Cost Management budgets, then deletes the group and its VMSS, load balancer, workspace, alert, autoscale and data collection rule. **Deleting only the resource group can leave its budgets behind.**

```bash
export LAB_LANG=en
source .lab.env      # skip if already loaded
scripts/cleanup.sh
```

When prompted, type the resource group name (`rg-ha-ops-lab`). Deletion runs in the background (about 3-5 minutes).

```bash
az group exists -n rg-ha-ops-lab      # false means it is done
```

Options:

- `scripts/cleanup.sh -y` delete without confirmation
- `scripts/cleanup.sh --wait` wait until deletion finishes

Without `.lab.env`, the script does not automatically delete a default group. Check your Azure subscription first, then explicitly set the target with `RESOURCE_GROUP="<group you deployed>" scripts/cleanup.sh`. It cleans up remaining group-scoped budgets even if the group is already gone. Budget lookup/deletion requires the Cost Management permissions described in Module 4. If a lookup or deletion fails, the script exits with an error and keeps local files so you can fix the problem and retry.

## Checklist

- [ ] `az group exists` returns `false`
- [ ] Group-scoped budgets are also deleted by `cleanup.sh`
- [ ] Delete any subscription-scoped budget in the portal
- [ ] Delete the Codespace at [github.com/codespaces](https://github.com/codespaces) if you no longer need it (it stops automatically when idle, but storage remains)

Well done!
