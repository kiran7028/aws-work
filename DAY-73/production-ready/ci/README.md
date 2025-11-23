# CI Helper Scripts

These scripts run inside the Jenkins pipeline.

- `smoke_test_dev.sh` → validates dev rollout
- `integration_test_stage.sh` → runs deeper tests in stage
- `smoke_test_prod_canary.sh` → runs canary checks for prod

Make sure they are executable:
```
chmod +x ci/*.sh
```
