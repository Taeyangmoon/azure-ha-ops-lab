# Cleanup (5 min)

[← Module 4](04-cost.md) | [README](../../README.en.md)

Everything the lab created lives in one resource group. Deleting it removes the VMSS, load balancer, workspace, alert, autoscale, data collection rule and any budget scoped to the resource group.

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

## Checklist

- [ ] `az group exists` returns `false`
- [ ] Delete any subscription-scoped budget in the portal
- [ ] Delete the Codespace at [github.com/codespaces](https://github.com/codespaces) if you no longer need it (it stops automatically when idle, but storage remains)

Well done!
