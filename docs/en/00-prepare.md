# Module 0. Prepare (10 min)

[← README](../../README.en.md) | [Next: Module 1 →](01-high-availability.md)

## Goals

- Deploy the whole lab environment at once with Bicep (infrastructure as code).
- Understand what each component does.

## Resources created

| Resource | Role |
|---|---|
| VNet + NSG | Network for the web servers. The NSG allows only port 80 (HTTP) |
| Public IP + Azure Load Balancer (Standard) | Receives external requests and spreads them across healthy instances. A health probe (every 5 s) checks each instance |
| Virtual Machine Scale Set (2 instances) | Runs identical nginx web servers, spread across Availability Zones 1-3 |
| Log Analytics workspace | Stores monitoring data and lets you query it with KQL |

Every resource gets the **tags** `project=azure-ha-ops-lab` and `env=workshop` (used in Module 4).

## Steps

### 1. Check your login

```bash
az login --use-device-code      # if you have not signed in yet
az account show --query name -o tsv
```

> With multiple subscriptions, pick one: `az account set --subscription "<name or ID>"`.

### 2. Deploy

```bash
export LAB_LANG=en              # English script messages
scripts/deploy.sh
```

It takes about 5-8 minutes. While you wait, open [`infra/main.bicep`](../../infra/main.bicep) to see how the table above looks as code.

Defaults are region `koreacentral` and size `Standard_B2s`. To change them:

```bash
LOCATION=japaneast VM_SIZE=Standard_D2s_v5 scripts/deploy.sh
```

### 3. Load the variables

```bash
source .lab.env
echo $LB_IP
```

These variables (`RG`, `VMSS`, `LB_IP`, `WORKSPACE`, ...) are used in later modules. **In a new terminal, run `source .lab.env` again.**

### 4. Verify

```bash
curl http://$LB_IP/whoami.txt
az vmss list-instances -g $RG -n $VMSS --query "[].{id:instanceId, name:osProfile.computerName, zone:zones[0], state:provisioningState}" -o table
```

You can also open `http://<LB_IP>` in a browser. If you see an instance name, you are good.

## Troubleshooting

| Symptom | Fix |
|---|---|
| `QuotaExceeded` / not enough cores | Use another region or change `VM_SIZE`. Check quota: `az vm list-usage -l $LOCATION -o table` |
| `SkuNotAvailable` / zone errors | `USE_ZONES=false scripts/deploy.sh` (region/size without zone support) |
| `curl` gets no response after deploy | The instances are still installing nginx. Retry in 1-3 minutes |
| Name conflict | `RESOURCE_GROUP=rg-ha-ops-lab2 scripts/deploy.sh` |

Next → [Module 1. High availability](01-high-availability.md)
