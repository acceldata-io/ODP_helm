# ODP Helm Chart

This Helm chart deploys an **Open Data Platform (ODP)** cluster on Kubernetes. The ODP cluster includes big data components like Ambari, HDFS, YARN, Hive, HBase, Spark, and other Hadoop ecosystem tools running in containerized environments.

## What This Chart Does

- **Deploys ODP Cluster**: Creates a multi-node ODP cluster with configurable components
- **Auto-detects Versions**: Automatically selects Python and JDK versions based on ODP version
- **Flexible Configuration**: Supports different operating systems, databases, and deployment modes
- **High Availability**: Optional HA configuration for production deployments
- **Kerberos Security**: Built-in Kerberos authentication support
- **Custom Images**: Automatically generates appropriate Docker images based on configuration

## Architecture

The chart creates:
- **StatefulSet**: Multi-node ODP cluster (default: 3 nodes)
- **ConfigMap**: Configuration scripts and parameters
- **Service**: Exposes SSH (22), HTTP (8080), and HTTPS (8443) ports
- **Secret**: Optional Ansible token for automation

## Quick Start

### Prerequisites

- Kubernetes cluster with sufficient resources
- User kubeconfig yaml to access to that cluster
- prerequisite installations of helm, kubectl, k9s which can be done using

```bash
curl -sSL https://mirror.odp.acceldata.dev/ODP/kubernetes/setup_local.sh | bash
source ~/.config/envman/PATH.env
```

- Download kubeconfig freshly from rancher ui and export as shown below

```bash
export KUBECONFIG=sandbox.yml
```

- To connect to k8s DNS for hostname resolution

```bash
telepresence connect
```



### Add Helm Repository

To list exising repos

```bash
helm repo list
```

To clean existing stale charts

```bash
helm repo remove <repo name>
```

To update a helm repo

```bash
helm repo update
```

To use this chart, you need to add the ODP Helm repository to your local Helm installation:

```bash
helm repo add odp-deployer https://github.com/acceldata-io/ODP_helm/raw/{{branch}}
```

## Custom Installation

### 1. Create Your Values File

Copy the sample values file and customize it for your environment:

```bash
# Copy sample values
cp sample_Values.yml my-odp-rhel8-v3.3.6.yml

# Edit the file for your specific needs
vim my-odp-rhel8-v3.3.6.yml
```

### 2. Example Custom Values Files

#### **For RHEL8 with ODP 3.3.6**
```yaml
# my-odp-rhel8-v3.3.6.yml
## Operating sys options : centos7, rhel8, rhel8, ubuntu20, ubuntu22
OperatingSystem: rhel8

# number of nodes / containers in cluster
nodes: 1                              # Upto 7 nodes

# "AMBARI,HDFS,ZOOKEEPER,YARN,MAP-REDUCE,INFRA-SOLR,HIVE,TEZ,HBASE,SQOOP,RANGER,RANGER-KMS,DRUID,OOZIE,IMPALA, HUE, SPARK3, KAFKA, KNOX, ZEPPELIN, HTTPFS,FLINK, KAFKA3, CRUISE_CONTROL3, IMPALA, PINOT, REGISTRY, AIRFLOW, NIFI, NIFI_REGISTRY, HUE"
Components: "AMBARI,HDFS,ZOOKEEPER,YARN,MAP-REDUCE,INFRA-SOLR,HIVE,TEZ"

AmbariVersion: "2.7.9.1-1"
AmbariUrl: "https://mirror.odp.acceldata.dev/v2/ambari/python3/jdk11/2.7.9.1-1/releases/rhel8/"

OdpVersion: "3.3.6.1-1"
OdpUrl: "https://mirror.odp.acceldata.dev/v2/odp/python3/jdk11/3.3.6.1-1/releases/rhel8/"

UtilsUrl: "https://mirror.odp.acceldata.dev/v2/odp-utils/centos8/"
MpackUrl: "https://mirror.odp.acceldata.dev/v2/odp/python3/jdk11/3.3.6.1-1/mpacks/"

Kerberos: "Yes"                           # Yes or No

```

### 3. Install with Custom Values

```bash
# Install with your custom values file
helm install {cluster name} odp-deployer/ODP-cluster -n {namespace} -f my-odp-rhel8-v3.3.6.yml
```

### 4. Start Cluster deployment

```bash
kubectl exec -n {namespace} {cluster name}-0 -- bash /config/bashexec.sh
```

## Configuration Options

### Core Settings

| Parameter | Description | Default | Example |
|-----------|-------------|---------|---------|
| `OperatingSystem` | OS for container images | `rhel8` | `rhel8`, `ubuntu22` |
| `OdpVersion` | ODP version to deploy | Required | `3.3.6.1-1`, `3.2.3.3-3` |
| `nodes` | Number of cluster nodes | `3` | `3`, `4` |
| `Kerberos` | Enable Kerberos security | `Yes` | `Yes`, `No` |
| `HA` | Enable High Availability | `No` | `Yes`, `No` |
| `Database` | Database backend | `mysql` | `mysql`, `postgres`, `oracle`, `mariadb` |

### Advanced Settings

| Parameter | Description | Default |
|-----------|-------------|---------|
| `dockerRepository` | Docker registry/repository | `harshith212` |
| `Components` | Specific components to install | `"AMBARI,HDFS,ZOOKEEPER,YARN,MAP-REDUCE"` |
| `pythonVersion` | Override Python version | Auto-detected |
| `jdkVersion` | Override JDK version | Auto-detected |
| `image` | Override container image | Auto-generated |

### Auto-Detection Logic

The chart automatically detects versions based on `OdpVersion`:

- **ODP 3.3.x**: Python 3.11, JDK 11
- **ODP 3.x.x.x-3**: Python 3.11, JDK 8  
- **Others**: Python 2, JDK 8

## Troubleshooting

### Common Issues

1. **Image Pull Errors**: Ensure your `dockerRepository` is accessible
2. **Resource Limits**: Increase cluster resources if pods fail to start
3. **Secret Missing**: Create `ansible-token` secret if using automation
4. **Version Mismatch**: Verify `OdpVersion` matches available images


## Uninstalling

```bash
# Remove the deployment
helm uninstall my-odp-cluster -n my-namespace
```

## Support

For issues and questions:
- Check the troubleshooting section above
- Review Kubernetes events: `kubectl get events -n my-namespace`
- Examine pod logs for detailed error messages

