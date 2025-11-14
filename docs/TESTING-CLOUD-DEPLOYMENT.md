# Testing Cloud Deployment Feature

Quick guide to test the complete end-to-end cloud deployment workflow.

## Prerequisites

- ✅ AWS or Azure account with credentials configured
- ✅ SSH key generated (`ssh_keys/id_rsa` and `ssh_keys/id_rsa.pub`)
- ✅ Cloud credentials in `.env` file:
  ```env
  AWS_ACCESS_KEY_ID=...
  AWS_SECRET_ACCESS_KEY=...
  AWS_REGION=us-east-2
  ```

## Local Testing (Recommended First)

Test the web dashboard locally before deploying to production:

### 1. Start Local Dashboard

```bash
# Make sure backend has terraform and ansible access
docker compose -f docker-compose.web.yml up -d

# Check logs
docker compose -f docker-compose.web.yml logs -f web-backend
```

### 2. Access Dashboard

Open browser: <http://localhost>

### 3. Test Local Deployment (Baseline)

1. Click "**+ New Server**"
2. Fill form:
   - Name: `test-local`
   - Type: `paper`
   - Version: `1.20.1`
   - Provider: `Local Docker` ← Keep default
3. Click "**Create**"
4. Console should open automatically
5. Watch Minecraft server start

**Expected**: Server deploys in ~30 seconds, console shows Minecraft logs.

### 4. Test Cloud Deployment (AWS)

1. Click "**+ New Server**" again
2. Fill form:
   - Name: `test-aws`
   - Type: `paper`
   - Version: `1.20.1`
   - Provider: `AWS Cloud` ← **Change this**
   - Orchestration: `Docker Swarm`
   - Server Names: `instance1`
3. Click "**Create**"
4. **Cloud Deployment Progress Modal** should appear
5. Watch real-time progress:

   ```
   Status: Initializing Terraform...

   ⏳ Terraform Infrastructure
      In Progress...

   ⏸ Ansible Configuration
      Pending

   Deployment Logs:
   [TERRAFORM] Initializing Terraform...
   [TERRAFORM] terraform init
   [TERRAFORM] Initializing provider plugins...
   [TERRAFORM] terraform plan
   [TERRAFORM] Plan: 5 to add, 0 to change, 0 to destroy
   [TERRAFORM] terraform apply
   [TERRAFORM] Apply complete! Resources: 5 added
   [ANSIBLE] Testing connectivity to 3.142.156.78...
   [ANSIBLE] Running playbook swarm_setup.yml...
   [ANSIBLE] PLAY [Configure Minecraft Server]
   [ANSIBLE] TASK [Setup Docker]
   ...

   Server Address:
   3.142.156.78:25565
   ```

**Expected**:
- Terraform stage: ~3-5 minutes (creates VPC, EC2, security groups)
- Ansible stage: ~5-7 minutes (installs Docker, deploys Swarm, pulls Minecraft image)
- Total: ~8-12 minutes
- Final: Server IP displayed, can connect with Minecraft client

### 5. Verify Deployment

```bash
# SSH to server
ssh -i ssh_keys/id_rsa ubuntu@<SERVER_IP>

# Check Docker containers
docker ps

# Should see:
# - Minecraft server container
# - Traefik proxy
# - Monitoring (Prometheus, Grafana)
```

### 6. Connect with Minecraft Client

1. Open Minecraft Java Edition 1.20.1
2. Multiplayer → Add Server
3. Server Address: `<SERVER_IP>:25565`
4. Connect!

### 7. Clean Up

**Option A: From Dashboard**
- Find server in list
- Click "**Delete**" button
- Confirm deletion

**Option B: Manual Terraform Destroy**
```bash
cd terraform/aws
terraform destroy -auto-approve
```

**Option C: Verify Cleanup**
```bash
./verify-destruction.sh --provider aws
```

---

## Production Testing (mineclifford.com)

After local testing succeeds, deploy to production:

### 1. Setup Cloudflare DNS

```bash
cd terraform/cloudflare

# Configure variables
export TF_VAR_cloudflare_api_token="your_token"
export TF_VAR_platform_ip="YOUR_SERVER_IP"

# Apply
terraform apply
```

### 2. Deploy Platform with Traefik

```bash
# Generate BasicAuth password
./scripts/generate-basicauth.sh admin YourSecurePassword123

# Add to .env:
# TRAEFIK_DASHBOARD_PASSWORD_HASH=admin:$$2y$$05$$...

# Start platform
docker compose -f docker-compose.traefik.yml up -d

# Check logs
docker compose -f docker-compose.traefik.yml logs -f
```

### 3. Access Production Dashboard

Open browser: <https://mineclifford.com>

- Username: `admin` (or what you set)
- Password: Your password from step 2

### 4. Test Cloud Deployment (Same as Above)

Follow steps 4-7 from Local Testing, but using the production dashboard.

---

## Troubleshooting

### WebSocket Connection Fails

**Symptom**: Deployment modal shows "Connection Error"

**Fix**:
```bash
# Check backend logs
docker logs mineclifford-backend

# Verify WebSocket route
curl -i -N \
  -H "Connection: Upgrade" \
  -H "Upgrade: websocket" \
  http://localhost:8000/api/servers/deploy-cloud/test-id
```

### Terraform Fails

**Symptom**: "terraform: command not found"

**Fix**:
```bash
# Install Terraform in backend container
docker exec mineclifford-backend terraform version

# If missing, add to Dockerfile:
# RUN apt-get update && apt-get install -y terraform
```

### Ansible Fails

**Symptom**: "UNREACHABLE! => Connection timed out"

**Fix**:
```bash
# Check SSH key permissions
ls -la ssh_keys/
chmod 600 ssh_keys/id_rsa
chmod 644 ssh_keys/id_rsa.pub

# Check security group allows SSH from backend container IP
# (Terraform should handle this automatically)
```

### Deployment Never Completes

**Symptom**: Stuck on "Applying infrastructure..."

**Check Terraform Logs**:
```bash
# SSH into backend container
docker exec -it mineclifford-backend bash

# Check Terraform state
cd /app/terraform/aws
terraform show

# Check for errors
terraform plan
```

### Can't Connect to Minecraft Server

**Symptom**: Connection refused

**Fix**:
1. Check server is running:
   ```bash
   ssh ubuntu@<SERVER_IP>
   docker ps | grep minecraft
   ```

2. Check security group allows port 25565:
   ```bash
   aws ec2 describe-security-groups \
     --filters "Name=tag:Project,Values=mineclifford" \
     --query "SecurityGroups[*].IpPermissions"
   ```

3. Try direct connection:
   ```bash
   telnet <SERVER_IP> 25565
   ```

---

## Expected Deployment Timeline

| Stage | Duration | Activities |
|-------|----------|------------|
| **Create Server (DB)** | <1s | POST /api/servers/ |
| **WebSocket Connect** | <1s | ws://api.../deploy-cloud/{id} |
| **Terraform Init** | 10-30s | Download providers, modules |
| **Terraform Plan** | 10-20s | Plan infrastructure changes |
| **Terraform Apply** | 2-4min | Create VPC, EC2, SG, EIP |
| **Ansible Connectivity** | 5-10s | Test SSH connection |
| **Ansible Playbook** | 4-6min | Install Docker, deploy services |
| **Total** | **8-12min** | End-to-end cloud deployment |

---

## Success Criteria

✅ **Frontend**:
- [x] Provider dropdown shows AWS/Azure options
- [x] Cloud options panel appears when cloud provider selected
- [x] Deployment modal opens after clicking Create
- [x] WebSocket connection established
- [x] Real-time logs stream in modal
- [x] Stage indicators update (Terraform, Ansible)
- [x] Final server IP displayed

✅ **Backend**:
- [x] WebSocket endpoint `/api/servers/deploy-cloud/{id}` responds
- [x] Terraform executor runs init, plan, apply
- [x] Ansible executor runs playbook
- [x] Database updated with server IP
- [x] No errors in backend logs

✅ **Infrastructure**:
- [x] AWS/Azure resources created (VPC, EC2, etc.)
- [x] SSH access works
- [x] Docker containers running on server
- [x] Minecraft server accessible on port 25565

✅ **Cleanup**:
- [x] Terraform destroy removes all resources
- [x] verify-destruction.sh reports no orphaned resources

---

## Next Steps After Successful Test

1. **Document any issues** encountered
2. **Measure actual deployment time** (is 8-12min acceptable?)
3. **Test with Azure** provider
4. **Test Kubernetes** orchestration (instead of Swarm)
5. **Implement user authentication** (remove BasicAuth)
6. **Add cost estimation** (show estimated monthly cost before deployment)
7. **Add deployment queue** (if multiple users deploy at once)

---

## Demo Video Script (For Documentation)

1. Open <http://localhost> or <https://mineclifford.com>
2. Login with BasicAuth (if production)
3. Show empty dashboard
4. Click "New Server"
5. **Switch to AWS Cloud** provider
6. Show cloud options appear
7. Fill server name: "demo-aws-server"
8. Click Create
9. **Show deployment modal open**
10. Narrate each stage:
    - "Terraform is now provisioning AWS infrastructure"
    - "Creating VPC, subnet, security group, EC2 instance..."
    - "Infrastructure complete, IP assigned: 3.142.156.78"
    - "Ansible is now configuring the server"
    - "Installing Docker, deploying Minecraft..."
11. **Show final result**: Server address displayed
12. Open Minecraft client
13. Add server with IP
14. Connect and show working server
15. Return to dashboard
16. Delete server
17. Show cleanup in progress

---

**Ready to test? Start with local testing first!**

```bash
docker compose -f docker-compose.web.yml up -d
# Open http://localhost
```
