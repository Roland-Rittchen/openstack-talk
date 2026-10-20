# From Sovereignty to Liberty

One OpenStack foundation, a Kubernetes platform, and a notes app that can move between clouds.
The talk demonstrated Local Kolla and ScaleUp/SCS, including PostgreSQL backups and cross-cloud recovery.
OVH is an example target; its full platform was blocked by security-group eligibility.

```text
app/                    Notes app + container image; SQLite or PostgreSQL
bootstrap/local/        Optional cloud-admin setup: external network and flavors
bootstrap/kubernetes/   Cloud controller, Flux wiring and database operators
capi/                   Shared Cluster API / OpenStack workload templates
config/                 Pinned releases, upstream checksums and runtime examples
opentofu/environments/  Local, OVH and SCS inputs; identical main.tf files
opentofu/modules/       Network, buckets, image/flavor lookup and k3s foundation
packer/                 Common Ubuntu / kubeadm image and provider input examples
flux/                   Shared ingress/app; PostgreSQL + S3 backup stage
```

OpenTofu owns a network, router, two security groups, SSH key, bootstrap VM, Cinder data volume,
floating IP and S3 buckets. CAPO adds a separate control plane and worker on that network.
Flux manages the platform. Cloud load balancers forward L4 traffic to ingress-nginx; Local uses
NodePort with the same Ingress objects. Provider differences stay in inputs and small overlays.

## Recreate it

These are building blocks with explicit configuration points. Bring OpenTofu ≥1.10, the OpenStack CLI,
Packer, Docker, kubectl, Flux, clusterctl and optionally kind. Pins are in `config/releases.yaml`;
upstream manifest checksums are in `config/upstream-lock.json`. Commands below run from the repo root.

1. **Prepare the project.** You need Nova, Neutron (security groups and floating IPs), Glance,
   Cinder and HTTPS S3. Cloud overlays also require Octavia. Check quota and catalog values.
   `bootstrap/local/` optionally creates lab flavors and an external network; copy its input example
   and reserve an address range outside LAN DHCP. This step needs cloud-admin privileges.

2. **Set inputs.** In the chosen OpenTofu environment, copy `clouds.yaml.example` and
   `terraform.tfvars.example` without `.example`. Fill project-scoped Keystone application credentials,
   catalog mappings, SSH public key, restricted access CIDRs and S3 settings. Supply S3 keys through
   `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY`. Credentials and state stay outside Git.

   ```sh
   export ENVIRONMENT=local  # or scs / ovh
   export OS_CLOUD="$ENVIRONMENT"
   export OS_CLIENT_CONFIG_FILE="$PWD/opentofu/environments/$ENVIRONMENT/clouds.yaml"
   umask 077
   mkdir -p .generated
   openstack catalog list
   ```

3. **Build the image.** Copy `packer/vars/$ENVIRONMENT.pkrvars.hcl.example` without `.example`.
   Supply an existing build network and security group allowing workstation SSH and outbound downloads.
   Review the common pins; use the resulting image name in your OpenTofu inputs.

   ```sh
   packer init packer/kubeadm.pkr.hcl
   packer build -var-file=packer/common.pkrvars.hcl \
     -var-file="packer/vars/$ENVIRONMENT.pkrvars.hcl" packer/kubeadm.pkr.hcl
   ```

4. **Apply OpenTofu.** For a new SCS/OVH deployment, first copy Local's `backend.tf` into the selected
   environment as `backend_override.tf`; the remote state bucket does not exist yet. Local needs no override.

   ```sh
   tofu -chdir="opentofu/environments/$ENVIRONMENT" init
   tofu -chdir="opentofu/environments/$ENVIRONMENT" plan -out=deployment.tfplan
   tofu -chdir="opentofu/environments/$ENVIRONMENT" apply deployment.tfplan
   tofu -chdir="opentofu/environments/$ENVIRONMENT" output -json platform > .generated/platform.json
   ```

   The VM starts k3s on Cinder. Retrieve its `/etc/rancher/k3s/k3s.yaml` securely and set the server
   to the output floating IP. For remote state: test private S3 access and conditional-write locking,
   checkpoint state, fill `backend.hcl` from its example, remove the override, then run
   `tofu init -migrate-state -backend-config=backend.hcl` **inside that environment directory**.

5. **Add CAPO.** Use kind or the foundation k3s as management. Install the pinned CAPI, kubeadm and
   CAPO providers with clusterctl, the separate ORC manifest, and Flux. Fill/apply
   `config/capi-values.yaml.example` from the foundation outputs. In namespace `capi-$ENVIRONMENT`,
   create `<CLUSTER_NAME>-cloud-config` with a `clouds.yaml` key and optional `cacert` key.
   Render/apply `bootstrap/kubernetes/capi-flux.yaml` with your published fork's `GIT_REPOSITORY_URL`,
   `GIT_BRANCH` and `ENVIRONMENT`. Review the paused resources before committing `spec.paused: false`.
   Patch AZ placement and kubeadm private DNS/CA configuration if needed. Export the workload kubeconfig
   with `clusterctl get kubeconfig`. The original k3s cluster remains a separate bootstrap/fallback.

6. **Initialize the workload.** Select its Kubernetes context. On CAPO, install pinned Flannel and
   local-path, plus `bootstrap/kubernetes/network-policy.yaml`; k3s already includes these functions.
   Copy/edit `config/cloud.conf.example` and create Secret `kube-system/cloud-config` with key `cloud.conf`
   (plus `ca.crt` for private trust). Copy/edit/source `config/ccm.env.example`, then render the cloud
   controller with `flux envsubst --strict < bootstrap/kubernetes/cloud-controller.yaml` and apply it.
   Use a unique cluster name and private API address; Local omits the `service` controller and disables
   Octavia in cloud.conf. Wait for Ready nodes, InternalIPs and removal of the cloud initialization taint.

7. **Reconcile the app.** Build/push `app/Dockerfile`; put its immutable digest in a copy of
   `config/platform-runtime.yaml.example`. A public image simplifies pulls; private images need a pull Secret.
   Install the pinned Flux release; apply that runtime ConfigMap and the selected `flux/clusters/…/values.yaml`
   with your hostname, S3 endpoint and bucket. Commit those values to your fork. Local uses `[]` for LB ranges.
   Render/apply `bootstrap/kubernetes/flux.yaml` using the same Git variables as above. It installs database
   operators and starts SQLite. Git publication replaces the talk's workstation-to-OCI workflow;
   `registry.yaml` is an optional OCI example.

8. **Enable PostgreSQL.** Create `demo/database-backup-credentials` with `ACCESS_KEY_ID`,
   `ACCESS_SECRET_KEY`, `AWS_REGION`, and `demo/database-backup-ca` with `ca.crt` (trusted CA bundle).
   Create Docker-config Secret `demo-image-pull`, or remove that reference for a public image.
   Set a unique `BACKUP_PREFIX` per database/cluster. Change Flux's platform path to
   `./flux/stages/postgres/clusters/$ENVIRONMENT`. The app imports SQLite once if its old PVC is retained;
   moving clusters needs recovery instead. Daily base backups start suspended: enable deliberately,
   verify WAL/base backups in S3, and test recovery separately before retiring the source.

## Verify and adapt

Check a clean OpenTofu plan, Ready CAPI machines/nodes, Flux at the intended revision, HTTP 200,
a note surviving restart, and a PostgreSQL restore from S3. Local HTTP uses port 30080; cloud ingress
uses its load-balancer address. Point DNS there. TLS belongs in Ingress; no certificate is configured by default.

This demo has one control plane and node-local workload volumes, not production HA. The foundation's
volume is Cinder-backed; CAPO uses local-path on VM disks. Refresh the CCM API address after control-plane
replacement. Flannel alone does not enforce NetworkPolicy; the supplied kube-router controller does.
S3 uses the AWS provider in endpoint/path-style mode because the OpenStack provider has no S3 resource.
Probe ACLs, locking, versioning and backup compatibility per endpoint. Flavor capacities, private DNS/CA trust,
compute/storage AZs and floating-IP API return paths also vary. Additional router/VM source /32 rules should
remain API-only; use the foundation's `api_server_access_cidrs` output for the CAPO listener allowlist.
