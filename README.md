# Rancher RKE Deployment on Crusoe Cloud

## Known Issues

If the Terraform below fails contact support@crusoecloud.com for help.

## Requirements

- [Terraform CLI](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli)
- [Crusoe Cloud CLI](https://docs.crusoecloud.com/quickstart/installing-the-cli/index.html)
- [Crusoe Cloud Credentials](https://docs.crusoecloud.com/account-management/managing-api-keys)
  - Either stored in `~/.crusoe/credentials` or exported as environment variables `CRUSOE_x`

## Deployment

To use as a module fill in the `variables` in your own `main.tf` file

```
module "crusoe" {
  source = "github.com/crusoecloud/crusoe-ml-rke2"
  ssh_privkey_path="</path/to/priv.key"
  ssh_pubkey="<pub_key>"
  worker_instance_type = "h100-80gb-sxm-ib.8x"
  worker_image = "ubuntu22.04-nvidia-sxm-docker:latest"
  worker_count = 2
  ib_partition_id = "6dcef748-dc30-49d8-9a0b-6ac87a27b4f8"
  headnode_instance_type="c1a.8x"
  deploy_location = "us-east1-a"
  # extra variables here
}
```

To use from this directory, fill in the `variables` in a `terraform.tfvars` file

```
ssh_privkey_path="</path/to/priv.key"
ssh_pubkey="<pub_key>"
worker_instance_type = "h100-80gb-sxm-ib.8x"
worker_image = "ubuntu22.04-nvidia-sxm-docker:latest"
worker_count = 2
ib_partition_id = "6dcef748-dc30-49d8-9a0b-6ac87a27b4f8"
headnode_instance_type="c1a.8x"
deploy_location = "us-east1-a"
# extra variables here
```

And then apply, to provision resources

```
terraform init
terraform plan
terraform apply
```

## Accessing the Cluster

Once the deployment is complete, you can access the cluster by copying the `kubeconfig` file from the headnode. Replace the 'server' address in the Kubeconfig with that of your load balancer (or control plane node when deploying single control plane node configurations). 

```bash
rke_endpoint=$(terraform output -raw rke-ingress-instance_public_ip)
headnode_endpoint=$(terraform output -raw rke-headnode-instance_public_ip)
scp -i $path_to_priv_key "root@${headnode_endpoint}:/etc/rancher/rke2/rke2.yaml" ./kubeconfig
# change the endpoint to the kubectl endpoint
sed -i '' "s/127.0.0.1/${rke_endpoint}/g" ./kubeconfig
# rename the context (optional)
sed -i '' "s/default/crusoe/g" ./kubeconfig
export KUBECONFIG="$(pwd)/kubeconfig"
```

## Nvidia GPU Support

For nodes with Nvidia GPUs, you can run the following commands to install the Nvidia GPU operators (along with the Network operator when using IB-enabled nodes) to ensure they are available for use by pods provisioned in the cluster. 

```bash
helm repo add nvidia https://helm.ngc.nvidia.com/nvidia
helm repo update
helm install --wait --generate-name -n gpu-operator --create-namespace nvidia/gpu-operator --set driver.rdma.enabled=true --set driver.rdma.useHostMofed=true
helm install network-operator nvidia/network-operator -n nvidia-network-operator --create-namespace -f ./gpu-operator/values.yaml --wait
```

To test the GPU infiniband speeds, you can run the following commands.

```bash
kubectl apply -f https://raw.githubusercontent.com/kubeflow/mpi-operator/v0.4.0/deploy/v2beta1/mpi-operator.yaml
kubectl apply -f examples/nccl-tests.yaml
```

## Verifying NCCL performance across 2 worker nodes
```bash
[1,0]<stdout>:           8             2     float     sum      -1    115.8    0.00    0.00      0    57.98    0.00    0.00      0
[1,0]<stdout>:          16             4     float     sum      -1    62.97    0.00    0.00      0    65.20    0.00    0.00      0
[1,0]<stdout>:          32             8     float     sum      -1    63.93    0.00    0.00      0    54.90    0.00    0.00      0
[1,0]<stdout>:          64            16     float     sum      -1    61.56    0.00    0.00      0    64.40    0.00    0.00      0
[1,0]<stdout>:         128            32     float     sum      -1    64.07    0.00    0.00      0    54.52    0.00    0.00      0
[1,0]<stdout>:         256            64     float     sum      -1    60.12    0.00    0.01      0    64.40    0.00    0.01      0
[1,0]<stdout>:         512           128     float     sum      -1    67.30    0.01    0.01      0    53.60    0.01    0.02      0
[1,0]<stdout>:        1024           256     float     sum      -1    55.13    0.02    0.03      0    71.49    0.01    0.03      0
[1,0]<stdout>:        2048           512     float     sum      -1    60.65    0.03    0.06      0    57.86    0.04    0.07      0
[1,0]<stdout>:        4096          1024     float     sum      -1    58.77    0.07    0.13      0    58.57    0.07    0.13      0
[1,0]<stdout>:        8192          2048     float     sum      -1    59.48    0.14    0.26      0    58.58    0.14    0.26      0
[1,0]<stdout>:       16384          4096     float     sum      -1    74.41    0.22    0.41      0    64.55    0.25    0.48      0
[1,0]<stdout>:       32768          8192     float     sum      -1    72.30    0.45    0.85      0    78.95    0.42    0.78      0
[1,0]<stdout>:       65536         16384     float     sum      -1    82.01    0.80    1.50      0    69.39    0.94    1.77      0
[1,0]<stdout>:      131072         32768     float     sum      -1    93.80    1.40    2.62      0    76.66    1.71    3.21      0
[1,0]<stdout>:      262144         65536     float     sum      -1    81.48    3.22    6.03      0    80.95    3.24    6.07      0
[1,0]<stdout>:      524288        131072     float     sum      -1    87.75    5.97   11.20      0    83.72    6.26   11.74      0
[1,0]<stdout>:     1048576        262144     float     sum      -1    120.2    8.72   16.35      0    83.11   12.62   23.66      0
[1,0]<stdout>:     2097152        524288     float     sum      -1    117.1   17.91   33.57      0    112.6   18.63   34.94      0
[1,0]<stdout>:     4194304       1048576     float     sum      -1    94.94   44.18   82.83      0    128.0   32.78   61.46      0
[1,0]<stdout>:     8388608       2097152     float     sum      -1    211.9   39.60   74.24      0    214.2   39.16   73.42      0
[1,0]<stdout>:    16777216       4194304     float     sum      -1    256.4   65.44  122.69      0    200.4   83.74  157.01      0
[1,0]<stdout>:    33554432       8388608     float     sum      -1    262.1  128.00  240.01      0    262.0  128.07  240.13      0
[1,0]<stdout>:    67108864      16777216     float     sum      -1    476.1  140.95  264.28      0    474.3  141.49  265.29      0
[1,0]<stdout>:   134217728      33554432     float     sum      -1    743.9  180.42  338.29      0    745.6  180.02  337.54      0
[1,0]<stdout>:   268435456      67108864     float     sum      -1   1282.2  209.36  392.55      0   1286.7  208.63  391.18      0
[1,0]<stdout>:   536870912     134217728     float     sum      -1   2480.6  216.43  405.80      0   2481.4  216.36  405.67      0
[1,0]<stdout>:  1073741824     268435456     float     sum      -1   4531.0  236.98  444.33      0   4550.3  235.97  442.45      0
[1,0]<stdout>:  2147483648     536870912     float     sum      -1   9025.7  237.93  446.12      0   9064.7  236.91  444.20      0
```

The `examples/nccl-tests.yaml` file explains more on how to run tests across your worker nodes.

## Troubleshooting

Here are some common troubleshooting steps you can take if you encounter any issues.

### Issue 1 Hostdev and GPU resources not allocatable across all nodes
When performing a kubectl describe node $node_name, you may notice `nvidia/hostdev: 0` or `nvidia/gpu: 0` as this resource is not allocatable. These resources need to be allocatable to use IB for NCCL testing.

### Resolution
Run the following commands to uninstall the `network-operator` and `gpu-operator` and delete the namespaces.

```bash
helm list -A
helm uninstall <gpu-operator-release-name> -n gpu-operator
helm uninstall network-operator -n nvidia-network-operator
kubectl delete namespace gpu-operator
kubectl delete namespace nvidia-network-operator
```
Then run the helm install commands again and see if the resources are allocatable.

### Issue #2 Running NCCL Tests across workers
When running NCCL performance tests across worker nodes, the worker-launcher pod may get scheduled on control plane nodes. This will not work and will provide an invalid test.

### Resolution 
Apply a taint to the control plane nodes so that the NCCL test pods do not get scheduled on them

```bash
kubectl taint nodes crusoe-rke-0.eu-iceland1-a.compute.internal node-role.kubernetes.io/control-plane=:NoSchedule
kubectl taint nodes crusoe-rke-1.eu-iceland1-a.compute.internal node-role.kubernetes.io/control-plane=:NoSchedule
```

Then verify a taint has been applied on the control plane nodes

```bash
kubectl describe node crusoe-rke-0.eu-iceland1-a.compute.internal | grep Taints
kubectl describe node crusoe-rke-1.eu-iceland1-a.compute.internal | grep Taints
```

To remove the taint, run the command:

```bash
kubectl taint nodes crusoe-rke-0.eu-iceland1-a.compute.internal node-role.kubernetes.io/control-plan:NoSchedule-
kubectl taint nodes crusoe-rke-1.eu-iceland1-a.compute.internal node-role.kubernetes.io/control-plan:NoSchedule-
```

## Notes

The launcher pod has other tests installed from its docker image. The following tests are available in the `/opt/nccl-tests/build/` directory:

```bash
all_gather_perf
all_reduce_perf
alltoall_perf
broadcast_perf
gather_perf
hypercube_perf
reduce_perf
reduce_scatter_perf
scatter_perf
sendrecv_perf
timer.o
verifiable
```
