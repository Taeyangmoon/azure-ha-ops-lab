# Module 1. High availability (15 min)

[← Module 0](00-prepare.md) | [Next: Module 2 →](02-monitoring.md)

## Goals

- See the load balancer spread requests across instances.
- Confirm the service stays up when one instance stops.
- Understand how the **health probe** removes a failed instance automatically.

## Key concepts

- **Load balancing**: the Load Balancer distributes requests across several servers.
- **Health probe**: every 5 seconds the Load Balancer calls `/` on each instance. After 2 consecutive failures it stops sending requests there.
- **Availability Zones**: physically separate datacenters within a region. Instances are spread across zones, so a problem in one zone leaves the others serving.

## Step 1. Verify load balancing (5 min)

```bash
source .lab.env
scripts/curl-loop.sh 20
```

Expected result (instance names may differ):

```text
     9 web000000 (zone 1)
    11 web000001 (zone 2)
```

Both instances answer. You can also refresh `http://<LB_IP>` in a browser and watch the name change. (Browsers reuse connections and may stick to one instance; a private window or `curl` is more reliable.)

**In the portal**: resource group → `halab-lb` → **Settings > Backend pools** (2 instances), and **Monitoring > Metrics > Health Probe Status** should be 100%.

## Step 2. Stop one instance (5 min)

Open a second terminal (run `source .lab.env`) and keep sending requests.

```bash
# Terminal B: check the response every second
while true; do curl -s --max-time 2 -H 'Connection: close' http://$LB_IP/whoami.txt || echo "FAILED"; sleep 1; done
```

In the original terminal, stop (deallocate) instance 0.

```bash
az vmss deallocate -g $RG -n $VMSS --instance-ids 0
```

In terminal B you should see **only one instance name**, with no or very few `FAILED` lines. A few requests may fail right after the stop. That is the time the health probe needs to detect the failure (about 10 s).

```bash
scripts/curl-loop.sh 20      # only the remaining instance answers
az vmss list-instances -g $RG -n $VMSS --expand instanceView --query "[].{id:instanceId, name:osProfile.computerName, state:instanceView.statuses[?starts_with(code,'PowerState')].displayStatus | [0]}" -o table
```

## Step 3. Recover (3 min)

```bash
az vmss start -g $RG -n $VMSS --instance-ids 0
scripts/curl-loop.sh 20      # after 1-2 minutes both instances answer again
```

## Going further: what if only the process dies? (optional)

Even if the VM is running, a dead web server fails the probe and traffic is pulled away.

```bash
az vmss run-command invoke -g $RG -n $VMSS --instance-id 1 --command-id RunShellScript --scripts "systemctl stop nginx"
scripts/curl-loop.sh 20      # after about 10 s only instance 0 answers
az vmss run-command invoke -g $RG -n $VMSS --instance-id 1 --command-id RunShellScript --scripts "systemctl start nginx"
```

## Takeaways

- 2 instances + load balancer + health probe = the service survives one failure.
- But **someone has to know about the failure** to fix it. The next module lets you see inside the instances.
- Limitation: with only 2 instances, the survivor takes all the load. Module 3 improves this with autoscale.

Next → [Module 2. Monitoring](02-monitoring.md)
