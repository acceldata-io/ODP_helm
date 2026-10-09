#!/bin/bash
## file from helm chart
# Inputs: Java version, number of nodes, and cluster type
odpLabel=$1
java_version=$2
NoOfNodes=$3
kerberos_stat=$4
cluster_type=$5
ODP_VERSION=$6
AMBARI_VERSION=$7
odpUrl=$8
ambariUrl=$9
defaultOdpUtilsUrl="https://mirror.odp.acceldata.dev/ODP/centos/ODP-UTILS-1.1.0.22/centos8/"
odpUtilsUrl=${10:-$defaultOdpUtilsUrl}
pythonVersion=${11}
mpackUrl=${12}
database=${13}
HA_enabled=${14}

# Execute commands only on pod-0
if [[ $(hostname) == ${odpLabel}-0.* ]]; then
echo "Executing commands on pod-0"

# Check for upper limit on number of nodes
# if [ "$NoOfNodes" -gt 4 ]; then
#   echo "Error: Deployment supports a maximum of 4 nodes. Provided: $NoOfNodes" >&2
#   exit 1
# fi

# Detect the operating system
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
    VERSION=$VERSION_ID
elif [ -f /etc/redhat-release ]; then
    OS="rhel"
    VERSION=$(cat /etc/redhat-release | grep -oE '[0-9]+\.[0-9]+' | head -1)
elif [ -f /etc/centos-release ]; then
    OS="centos"
    VERSION=$(cat /etc/centos-release | grep -oE '[0-9]+' | head -1)
else
    echo "Unable to detect operating system"
    exit 1
fi

# Determine OS type and version
case $OS in
    "centos")
        if [[ $VERSION == "7"* ]]; then
            OS_TYPE="centos7"
        else
            OS_TYPE="centos$VERSION"
        fi
        ;;
    "rhel"|"rocky"|"almalinux")
        if [[ $VERSION == "8"* ]]; then
            OS_TYPE="rhel8"
        elif [[ $VERSION == "9"* ]]; then
            OS_TYPE="rhel9"
        else
            OS_TYPE="rhel$VERSION"
        fi
        ;;
    "ubuntu")
        if [[ $VERSION == "22.04" ]]; then
            OS_TYPE="ubuntu22"
        elif [[ $VERSION == "20.04" ]]; then
            OS_TYPE="ubuntu20"
        else
            OS_TYPE="ubuntu$VERSION"
        fi
        ;;
    *)
        echo "Unsupported operating system: $OS"
        exit 1
        ;;
esac

if ! command -v base64 >/dev/null 2>&1; then
    echo "Error: base64 command not found"
    exit 1
fi

GITHUB_TOKEN=$(echo $token | base64 -d)

# Check if ansible-hortonworks directory exists and navigate to it if present
if [ -d ~/ansible-hortonworks ]; then
    echo "Found existing ansible-hortonworks directory, using to it..."
else
    echo "No existing ansible-hortonworks directory found, will clone fresh repository..."
    # Every OS deploys from ansible-odp master now (the old per-OS repos
    # ansible-ubuntu/ansible-rhel8/ansible-centos7 are gone), so there is a
    # single clone here instead of a case on $OS_TYPE.
    echo "Cloning ansible-odp repository for $OS_TYPE"
    git clone -b master git@github.com:acceldata-io/ansible-odp.git
    #git clone -b master https://${GITHUB_TOKEN}@github.com/acceldata-io/ansible-odp.git
    mv ansible-odp ansible-hortonworks
fi




> ~/ansible-hortonworks/inventory/static

# Create the ansible inventory

slave_group_started=false
inventory_file=~/ansible-hortonworks/inventory/static
for ((i=0; i<NoOfNodes; i++)); do
  node_num=$((i+1))
  if [ $node_num -le 4 ]; then
      echo "[hdp-master0$node_num]" >> "$inventory_file"
      echo "master0$node_num ansible_host=${odpLabel}-${i}.${odpLabel} ansible_user=root ansible_port=22" >> "$inventory_file"
      echo "" >> "$inventory_file"
  else
      if [ "$slave_group_started" = false ]; then
          echo "[hdp-slave01]" >> "$inventory_file"
          slave_group_started=true
      fi
      echo "worker0$node_num ansible_host=${odpLabel}-${i}.${odpLabel} ansible_user=root ansible_port=22" >> "$inventory_file"
  fi
done

# Update ODP & Ambari URLs
echo -e "hdp_main_repo_url: \"${odpUrl}\"" >> ~/ansible-hortonworks/playbooks/roles/ambari-config/defaults/main.yml 
echo -e "gpl_repo_url: \"${odpUrl}\"" >> ~/ansible-hortonworks/playbooks/roles/ambari-config/defaults/main.yml
echo -e "utils_repo_url: \"${odpUtilsUrl}\"" >> ~/ansible-hortonworks/playbooks/roles/ambari-config/defaults/main.yml
echo -e "ambari_repo_url: \"${ambariUrl}\"" >> ~/ansible-hortonworks/playbooks/roles/ambari-repo/vars/rocky.yml 
echo -e "ambari_repo_url: \"${ambariUrl}\"" >> ~/ansible-hortonworks/playbooks/roles/ambari-repo/vars/debian-ubuntu.yml
echo -e "mpacks_url: \"${mpackUrl}\"" >> ~/ansible-hortonworks/playbooks/roles/ambari-config/defaults/main.yml

# Update Python version
if [[ "$pythonVersion" == *"311"* ]]; then
    sed -i "s/python: '2'/python: '311'/g" ansible-hortonworks/playbooks/group_vars/all* 
fi

# Setting database type
sed -i "s/database: '.*'/database: '${database}'/g" ansible-hortonworks/playbooks/group_vars/all*

# Java selection
if [[ $java_version == *"11"* ]]; then
    echo "Updating Java version to 11"
    sed -i "s/java-1.8.0-openjdk-devel/java-11-openjdk-devel/g" ~/ansible-hortonworks/playbooks/roles/common/vars/*.yml
    sed -i "s/openjdk-8-jdk/openjdk-11-jdk/g" ~/ansible-hortonworks/playbooks/roles/common/vars/*.yml
    sed -i "s/java-8-openjdk-amd64/java-11-openjdk-amd64/g" ~/ansible-hortonworks/playbooks/roles/ambari-server/vars/*.yml
    sed -i "s/java-1.8.0-openjdk/java-11-openjdk/g" ~/ansible-hortonworks/playbooks/roles/ambari-server/vars/*.yml
    sed -i "s/java-1.8.0-openjdk-amd64/java-1.11.0-openjdk-amd64/g" ~/ansible-hortonworks/playbooks/roles/ambari-server/vars/*.yml
    mv ~/ansible-hortonworks/playbooks/roles/ambari-blueprint/templates/blueprint_dynamic.j2 ~/ansible-hortonworks/playbooks/roles/ambari-blueprint/templates/blueprint_dynamic.j2_jdk8
    cp -r ~/ansible-hortonworks/playbooks/roles/ambari-blueprint/templates/blueprint_dynamic_jdk11.j2 ~/ansible-hortonworks/playbooks/roles/ambari-blueprint/templates/blueprint_dynamic.j2
fi

# Java 17 selection
if [[ $java_version == *"17"* ]]; then
    echo "Updating Java version to 17"
    sed -i "s/java-1.8.0-openjdk-devel/java-17-openjdk-devel/g" ~/ansible-hortonworks/playbooks/roles/common/vars/*.yml
    sed -i "s/openjdk-8-jdk/openjdk-17-jdk/g" ~/ansible-hortonworks/playbooks/roles/common/vars/*.yml
    sed -i "s/java-1.8.0-openjdk/java-17-openjdk/g" ~/ansible-hortonworks/playbooks/roles/ambari-server/vars/*.yml
    sed -i "s/java-1.8.0-openjdk-amd64/java-1.17.0-openjdk-amd64/g" ~/ansible-hortonworks/playbooks/roles/ambari-server/vars/*.yml
    sed -i "s/java-8-openjdk-amd64/java-17-openjdk-amd64/g" ~/ansible-hortonworks/playbooks/roles/ambari-server/vars/*.yml
    mv ~/ansible-hortonworks/playbooks/roles/ambari-blueprint/templates/blueprint_dynamic.j2 ~/ansible-hortonworks/playbooks/roles/ambari-blueprint/templates/blueprint_dynamic.j2_jdk8
    mv ~/ansible-hortonworks/playbooks/roles/ambari-blueprint/templates/blueprint_dynamic_jdk17.j2 ~/ansible-hortonworks/playbooks/roles/ambari-blueprint/templates/blueprint_dynamic.j2
fi

# Blueprint update
if [[ $NoOfNodes == "1" ]]; then
    echo "Switching to blueprint for 1 node"
    cp -rf ~/ansible-hortonworks/playbooks/group_vars/all_1_node ~/ansible-hortonworks/playbooks/group_vars/all
elif [[ $NoOfNodes == "2" ]]; then
    echo "Switching to blueprint for 2 nodes"
    cp -rf ~/ansible-hortonworks/playbooks/group_vars/all_2_node ~/ansible-hortonworks/playbooks/group_vars/all
elif [[ $NoOfNodes == "3" ]]; then
    if [[ $HA_enabled == "Yes" ]]; then
        echo "Switching to blueprint for 3 nodes with HA enabled"
        cp -rf ~/ansible-hortonworks/playbooks/group_vars/all_3_ha_node ~/ansible-hortonworks/playbooks/group_vars/all
    else
        echo "Switching to blueprint for 3 nodes"
        cp -rf ~/ansible-hortonworks/playbooks/group_vars/all_3_node ~/ansible-hortonworks/playbooks/group_vars/all
    fi
elif [[ $NoOfNodes == "4" ]]; then
    if [[ $HA_enabled == "Yes" ]]; then
        echo "Switching to blueprint for 4 nodes with HA enabled"
        cp -rf ~/ansible-hortonworks/playbooks/group_vars/all_4_ha_node ~/ansible-hortonworks/playbooks/group_vars/all
    else
        echo "Switching to blueprint for 4 nodes"
        cp -rf ~/ansible-hortonworks/playbooks/group_vars/all_4_node ~/ansible-hortonworks/playbooks/group_vars/all
    fi
else
    echo "Switching to blueprint for more than 4 nodes"
    cp -rf ~/ansible-hortonworks/playbooks/group_vars/all_multi_node ~/ansible-hortonworks/playbooks/group_vars/all
fi

# Update the version for ODP and AMBARI
bash ~/ansible-hortonworks/playbooks/change_version.sh $ODP_VERSION $AMBARI_VERSION

# Kerberos selection
if [[ $kerberos_stat == "No" ]]; then
    echo "Disabling Kerberos"
    sed -i "s/security: 'mit-kdc'/security: 'none'/g" ~/ansible-hortonworks/playbooks/group_vars/all
fi

# Component selection
echo "Configuring components..."

# Exact token match; substring matching let SOLR fire on INFRA-SOLR and KAFKA on KAFKA3.
has_component() {
    [[ ",${cluster_type// /}," == *",$1,"* ]]
}

if has_component "AMBARI"; then
    echo "Adding infra-solr"
    sed -i "s/#- AMBARI_SERVER/- AMBARI_SERVER/g" ~/ansible-hortonworks/playbooks/group_vars/all
fi

if has_component "INFRA-SOLR"; then
    echo "Adding INFRA_SOLR_CLIENT"
    sed -i "s/#, 'INFRA_SOLR_CLIENT'/, 'INFRA_SOLR_CLIENT'/g" ~/ansible-hortonworks/playbooks/group_vars/all
    sed -i "s/#- INFRA_SOLR/- INFRA_SOLR/g" ~/ansible-hortonworks/playbooks/group_vars/all
fi

if has_component "RANGER"; then
    echo "Adding Ranger"
    sed -i "s/#- RANGER_USERSYNC/- RANGER_USERSYNC/g" ~/ansible-hortonworks/playbooks/group_vars/all
    sed -i "s/#- RANGER_ADMIN/- RANGER_ADMIN/g" ~/ansible-hortonworks/playbooks/group_vars/all
fi

if has_component "RANGER-KMS"; then
    echo "Adding Ranger-KMS"
    sed -i "s/#- RANGER_KMS_SERVER/- RANGER_KMS_SERVER/g" ~/ansible-hortonworks/playbooks/group_vars/all
fi

if has_component "OOZIE"; then
    echo "Adding Oozie"
    sed -i "s/#, 'OOZIE_CLIENT'/, 'OOZIE_CLIENT'/g" ~/ansible-hortonworks/playbooks/group_vars/all
    sed -i "s/#- OOZIE_SERVER/- OOZIE_SERVER/g" ~/ansible-hortonworks/playbooks/group_vars/all
fi

if has_component "IMPALA"; then
    echo "Adding Impala"
    sed -i "s/#- IMPALA_DAEMON/- IMPALA_DAEMON/g" ~/ansible-hortonworks/playbooks/group_vars/all
    sed -i "s/#- IMPALA_STATE_STORE/- IMPALA_STATE_STORE/g" ~/ansible-hortonworks/playbooks/group_vars/all
    sed -i "s/#- IMPALA_CATALOG_SERVICE/- IMPALA_CATALOG_SERVICE/g" ~/ansible-hortonworks/playbooks/group_vars/all
fi

if has_component "SQOOP"; then
    echo "Adding Sqoop"
    sed -i "s/#, 'SQOOP'/, 'SQOOP'/g" ~/ansible-hortonworks/playbooks/group_vars/all
fi

if has_component "HUE"; then
    echo "Adding Hue"
    sed -i "s/#- HUE_SERVER/- HUE_SERVER/g" ~/ansible-hortonworks/playbooks/group_vars/all
fi

if has_component "MAP-REDUCE"; then
    echo "Adding Map reduce"
    sed -i "s/#, 'MAPREDUCE2_CLIENT'/, 'MAPREDUCE2_CLIENT'/g" ~/ansible-hortonworks/playbooks/group_vars/all
fi

if has_component "TEZ"; then
    echo "Adding Tez"
    sed -i "s/#, 'TEZ_CLIENT'/, 'TEZ_CLIENT'/g" ~/ansible-hortonworks/playbooks/group_vars/all
fi

if has_component "HIVE"; then
    echo "Adding Hive"
    sed -i "s/#, 'HIVE_CLIENT'/, 'HIVE_CLIENT'/g" ~/ansible-hortonworks/playbooks/group_vars/all
    sed -i "s/#- HIVE_SERVER/- HIVE_SERVER/g" ~/ansible-hortonworks/playbooks/group_vars/all
    sed -i "s/#- HIVE_METASTORE/- HIVE_METASTORE/g" ~/ansible-hortonworks/playbooks/group_vars/all
fi

if has_component "SPARK2"; then
    echo "Adding Spark2"
    sed -i "s/#, 'SPARK2_CLIENT'/, 'SPARK2_CLIENT'/g" ~/ansible-hortonworks/playbooks/group_vars/all
    sed -i "s/#- SPARK2_JOBHISTORYSERVER/- SPARK2_JOBHISTORYSERVER/g" ~/ansible-hortonworks/playbooks/group_vars/all
fi

if has_component "SPARK3"; then
    echo "Adding Spark3"
    sed -i "s/#, 'SPARK3_CLIENT'/, 'SPARK3_CLIENT'/g" ~/ansible-hortonworks/playbooks/group_vars/all
    sed -i "s/#- SPARK3_JOBHISTORYSERVER/- SPARK3_JOBHISTORYSERVER/g" ~/ansible-hortonworks/playbooks/group_vars/all
    sed -i "s/#- SPARK3_THRIFTSERVER/- SPARK3_THRIFTSERVER/g" ~/ansible-hortonworks/playbooks/group_vars/all
    sed -i "s/#- LIVY3_SERVER/- LIVY3_SERVER/g" ~/ansible-hortonworks/playbooks/group_vars/all
fi

if has_component "SPARK3_3_3_3"; then
    echo "Adding Spark3.3.3"
    sed -i "s/#, 'SPARK3_3_3_3_CLIENT'/, 'SPARK3_3_3_3_CLIENT'/g" ~/ansible-hortonworks/playbooks/group_vars/all
    sed -i "s/#- SPARK3_3_3_3_JOBHISTORYSERVER/- SPARK3_3_3_3_JOBHISTORYSERVER/g" ~/ansible-hortonworks/playbooks/group_vars/all
    sed -i "s/#- SPARK3_3_3_3_THRIFTSERVER/- SPARK3_3_3_3_THRIFTSERVER/g" ~/ansible-hortonworks/playbooks/group_vars/all
    sed -i "s/#- LIVY3_3_3_3_SERVER/- LIVY3_3_3_3_SERVER/g" ~/ansible-hortonworks/playbooks/group_vars/all
fi

if has_component "SPARK3_3_5_1"; then
    echo "Adding Spark3.5.1"
    sed -i "s/#, 'SPARK3_3_5_1_CLIENT'/, 'SPARK3_3_5_1_CLIENT'/g" ~/ansible-hortonworks/playbooks/group_vars/all
    sed -i "s/#- SPARK3_3_5_1_JOBHISTORYSERVER/- SPARK3_3_5_1_JOBHISTORYSERVER/g" ~/ansible-hortonworks/playbooks/group_vars/all
    sed -i "s/#- SPARK3_3_5_1_THRIFTSERVER/- SPARK3_3_5_1_THRIFTSERVER/g" ~/ansible-hortonworks/playbooks/group_vars/all
    sed -i "s/#- LIVY3_3_5_1_SERVER/- LIVY3_3_5_1_SERVER/g" ~/ansible-hortonworks/playbooks/group_vars/all
fi

if has_component "SPARK4"; then
    echo "Adding Spark4"
    sed -i "s/#, 'SPARK4_CLIENT'/, 'SPARK4_CLIENT'/g" ~/ansible-hortonworks/playbooks/group_vars/all
    sed -i "s/#- SPARK4_JOBHISTORYSERVER/- SPARK4_JOBHISTORYSERVER/g" ~/ansible-hortonworks/playbooks/group_vars/all
    sed -i "s/#- SPARK4_THRIFTSERVER/- SPARK4_THRIFTSERVER/g" ~/ansible-hortonworks/playbooks/group_vars/all
    sed -i "s/#- LIVY4_SERVER/- LIVY4_SERVER/g" ~/ansible-hortonworks/playbooks/group_vars/all
fi

if has_component "YARN"; then
    echo "Adding YARN"
    sed -i "s/#, 'YARN_CLIENT'/, 'YARN_CLIENT'/g" ~/ansible-hortonworks/playbooks/group_vars/all
    sed -i "s/#- RESOURCEMANAGER/- RESOURCEMANAGER/g" ~/ansible-hortonworks/playbooks/group_vars/all
    sed -i "s/#- NODEMANAGER/- NODEMANAGER/g" ~/ansible-hortonworks/playbooks/group_vars/all
    sed -i "s/#- YARN_REGISTRY_DNS/- YARN_REGISTRY_DNS/g" ~/ansible-hortonworks/playbooks/group_vars/all
    sed -i "s/#- TIMELINE_READER/- TIMELINE_READER/g" ~/ansible-hortonworks/playbooks/group_vars/all
    sed -i "s/#- HISTORYSERVER/- HISTORYSERVER/g" ~/ansible-hortonworks/playbooks/group_vars/all
    sed -i "s/#- APP_TIMELINE_SERVER/- APP_TIMELINE_SERVER/g" ~/ansible-hortonworks/playbooks/group_vars/all
fi

if has_component "KAFKA"; then
    echo "Adding Kafka"
    sed -i "s/#- KAFKA_BROKER/- KAFKA_BROKER/g" ~/ansible-hortonworks/playbooks/group_vars/all
    sed -i "s/#, 'KAFKA_CLIENT'/, 'KAFKA_CLIENT'/g" ~/ansible-hortonworks/playbooks/group_vars/all
fi

if has_component "HBASE"; then
    echo "Adding Hbase"
    sed -i "s/#, 'HBASE_CLIENT'/, 'HBASE_CLIENT'/g" ~/ansible-hortonworks/playbooks/group_vars/all
    sed -i "s/#- HBASE_REGIONSERVER/- HBASE_REGIONSERVER/g" ~/ansible-hortonworks/playbooks/group_vars/all
    sed -i "s/#- HBASE_MASTER/- HBASE_MASTER/g" ~/ansible-hortonworks/playbooks/group_vars/all
    sed -i "s/#- PHOENIX_QUERY_SERVER/- PHOENIX_QUERY_SERVER/g" ~/ansible-hortonworks/playbooks/group_vars/all
fi

if has_component "HDFS"; then
    echo "Adding HDFS"
    sed -i "s/#, 'HDFS_CLIENT'/, 'HDFS_CLIENT'/g" ~/ansible-hortonworks/playbooks/group_vars/all
    sed -i "s/#- SECONDARY_NAMENODE/- SECONDARY_NAMENODE/g" ~/ansible-hortonworks/playbooks/group_vars/all
    sed -i "s/#- DATANODE/- DATANODE/g" ~/ansible-hortonworks/playbooks/group_vars/all
    sed -i "s/#- NAMENODE/- NAMENODE/g" ~/ansible-hortonworks/playbooks/group_vars/all
    sed -i "s/#- ZKFC/- ZKFC/g" ~/ansible-hortonworks/playbooks/group_vars/all
    sed -i "s/#- JOURNALNODE/- JOURNALNODE/g" ~/ansible-hortonworks/playbooks/group_vars/all
fi

if has_component "DRUID"; then
    echo "Adding DRUID"
    sed -i "s/#- DRUID_BROKER/- DRUID_BROKER/g" ~/ansible-hortonworks/playbooks/group_vars/all
    sed -i "s/#- DRUID_COORDINATOR/- DRUID_COORDINATOR/g" ~/ansible-hortonworks/playbooks/group_vars/all
    sed -i "s/#- DRUID_HISTORICAL/- DRUID_HISTORICAL/g" ~/ansible-hortonworks/playbooks/group_vars/all
    sed -i "s/#- DRUID_MIDDLEMANAGER/- DRUID_MIDDLEMANAGER/g" ~/ansible-hortonworks/playbooks/group_vars/all
    sed -i "s/#- DRUID_OVERLORD/- DRUID_OVERLORD/g" ~/ansible-hortonworks/playbooks/group_vars/all
    sed -i "s/#- DRUID_ROUTER/- DRUID_ROUTER/g" ~/ansible-hortonworks/playbooks/group_vars/all
fi

if has_component "ZOOKEEPER"; then
    echo "Adding Zookeeper"
    sed -i "s/#'ZOOKEEPER_CLIENT'/'ZOOKEEPER_CLIENT'/g" ~/ansible-hortonworks/playbooks/group_vars/all
    sed -i "s/#- ZOOKEEPER_SERVER/- ZOOKEEPER_SERVER/g" ~/ansible-hortonworks/playbooks/group_vars/all
fi

if has_component "KNOX"; then
    echo "Adding KNOX"
    sed -i "s/#- KNOX_GATEWAY/- KNOX_GATEWAY/g" ~/ansible-hortonworks/playbooks/group_vars/all
fi

if has_component "ZEPPELIN"; then
    echo "Adding ZEPPELIN"
    sed -i "s/#- ZEPPELIN_MASTER/- ZEPPELIN_MASTER/g" ~/ansible-hortonworks/playbooks/group_vars/all
fi
if has_component "HTTPFS"; then
    echo "Adding HTTPFS"
    sed -i "s/#- HTTPFS_GATEWAY/- HTTPFS_GATEWAY/g" ~/ansible-hortonworks/playbooks/group_vars/all
fi

if has_component "JUPYTERHUB"; then
    echo "Adding JUPYTERHUB"
    sed -i "s/#- JUPYTERHUB/- JUPYTERHUB/g" ~/ansible-hortonworks/playbooks/group_vars/all
fi

if has_component "FLINK"; then
    echo "Adding FLINK"
    sed -i "s/#- FLINK_JOBHISTORYSERVER/- FLINK_JOBHISTORYSERVER/g" ~/ansible-hortonworks/playbooks/group_vars/all
    sed -i "s/#, 'FLINK_CLIENT'/, 'FLINK_CLIENT'/g" ~/ansible-hortonworks/playbooks/group_vars/all
fi

if has_component "KAFKA3"; then
    echo "Adding KAFKA3"
    sed -i "s/#- KAFKA3_MIRRORMAKER/- KAFKA3_MIRRORMAKER/g" ~/ansible-hortonworks/playbooks/group_vars/all
    sed -i "s/#- KAFKA3_BROKER/- KAFKA3_BROKER/g" ~/ansible-hortonworks/playbooks/group_vars/all
    sed -i "s/#- KAFKA3_CONNECT/- KAFKA3_CONNECT/g" ~/ansible-hortonworks/playbooks/group_vars/all
    sed -i "s/#, 'KAFKA3_CLIENT'/, 'KAFKA3_CLIENT'/g" ~/ansible-hortonworks/playbooks/group_vars/all
fi

if has_component "CRUISE_CONTROL3"; then
    echo "Adding CRUISE_CONTROL3"
    sed -i "s/#- CRUISE_CONTROL3/- CRUISE_CONTROL3/g" ~/ansible-hortonworks/playbooks/group_vars/all
fi

if has_component "IMPALA"; then
    echo "Adding IMPALA"
    sed -i "s/#- IMPALA_DAEMON/- IMPALA_DAEMON/g" ~/ansible-hortonworks/playbooks/group_vars/all
    sed -i "s/#- IMPALA_STATE_STORE/- IMPALA_STATE_STORE/g" ~/ansible-hortonworks/playbooks/group_vars/all
    sed -i "s/#- IMPALA_CATALOG_SERVICE/- IMPALA_CATALOG_SERVICE/g" ~/ansible-hortonworks/playbooks/group_vars/all
    sed -i "s/#, 'IMPALA_CLIENT'/, 'IMPALA_CLIENT'/g" ~/ansible-hortonworks/playbooks/group_vars/all
fi

if has_component "PINOT"; then
    echo "Adding PINOT"
    sed -i "s/#- PINOT_BROKER/- PINOT_BROKER/g" ~/ansible-hortonworks/playbooks/group_vars/all
    sed -i "s/#- PINOT_CONTROLLER/- PINOT_CONTROLLER/g" ~/ansible-hortonworks/playbooks/group_vars/all
    sed -i "s/#- PINOT_SERVER/- PINOT_SERVER/g" ~/ansible-hortonworks/playbooks/group_vars/all
    sed -i "s/#- PINOT_MINION/- PINOT_MINION/g" ~/ansible-hortonworks/playbooks/group_vars/all
fi

if has_component "KUDU"; then
    echo "Adding KUDU"
    sed -i "s/#- KUDU_TSERVER/- KUDU_TSERVER/g" ~/ansible-hortonworks/playbooks/group_vars/all
    sed -i "s/#- KUDU_MASTER/- KUDU_MASTER/g" ~/ansible-hortonworks/playbooks/group_vars/all
fi

if has_component "REGISTRY"; then
    echo "Adding REGISTRY"
    sed -i "s/#- REGISTRY_SERVER/- REGISTRY_SERVER/g" ~/ansible-hortonworks/playbooks/group_vars/all
fi

if has_component "OZONE"; then
    echo "Adding OZONE"
    sed -i "s/#- OZONE_STORAGE_CONTAINER_MANAGER/- OZONE_STORAGE_CONTAINER_MANAGER/g" ~/ansible-hortonworks/playbooks/group_vars/all
    sed -i "s/#- OZONE_DATANODE/- OZONE_DATANODE/g" ~/ansible-hortonworks/playbooks/group_vars/all
    sed -i "s/#- OZONE_S3_GATEWAY/- OZONE_S3_GATEWAY/g" ~/ansible-hortonworks/playbooks/group_vars/all
    sed -i "s/#- OZONE_MANAGER/- OZONE_MANAGER/g" ~/ansible-hortonworks/playbooks/group_vars/all
    sed -i "s/#- OZONE_RECON/- OZONE_RECON/g" ~/ansible-hortonworks/playbooks/group_vars/all
fi

if has_component "AIRFLOW"; then
    echo "Adding AIRFLOW"
    sed -i "s/#- AIRFLOW_SCHEDULER/- AIRFLOW_SCHEDULER/g" ~/ansible-hortonworks/playbooks/group_vars/all
    sed -i "s/#- AIRFLOW_WEBSERVER/- AIRFLOW_WEBSERVER/g" ~/ansible-hortonworks/playbooks/group_vars/all
    sed -i "s/#- AIRFLOW_WORKER/- AIRFLOW_WORKER/g" ~/ansible-hortonworks/playbooks/group_vars/all
fi

if has_component "NIFI"; then
    echo "Adding NIFI"
    sed -i "s/#- NIFI_MASTER/- NIFI_MASTER/g" ~/ansible-hortonworks/playbooks/group_vars/all
fi

if has_component "NIFI_REGISTRY"; then
    echo "Adding NIFI REGISTRY"
    sed -i "s/#- NIFI_REGISTRY_MASTER/- NIFI_REGISTRY_MASTER/g" ~/ansible-hortonworks/playbooks/group_vars/all
fi

if has_component "HUE"; then
    echo "Adding HUE"
    sed -i "s/#- HUE_SERVER/- HUE_SERVER/g" ~/ansible-hortonworks/playbooks/group_vars/all
fi

if has_component "TRINO"; then
    echo "Adding TRINO"
    sed -i "s/#- TRINO_COORDINATOR/- TRINO_COORDINATOR/g" ~/ansible-hortonworks/playbooks/group_vars/all
    sed -i "s/#- TRINO_WORKER/- TRINO_WORKER/g" ~/ansible-hortonworks/playbooks/group_vars/all
fi

if has_component "CLICKHOUSE"; then
    echo "Adding CLICKHOUSE"
    sed -i "s/#- CLICKHOUSE_KEEPER/- CLICKHOUSE_KEEPER/g" ~/ansible-hortonworks/playbooks/group_vars/all
    sed -i "s/#- CLICKHOUSE_SERVER/- CLICKHOUSE_SERVER/g" ~/ansible-hortonworks/playbooks/group_vars/all
    sed -i "s/#- CLICKHOUSE_WEBSERVER/- CLICKHOUSE_WEBSERVER/g" ~/ansible-hortonworks/playbooks/group_vars/all
fi

if has_component "MLFLOW"; then
    echo "Adding MLFLOW"
    sed -i "s/#- MLFLOW_SERVER/- MLFLOW_SERVER/g" ~/ansible-hortonworks/playbooks/group_vars/all
fi

if has_component "SUPERSET"; then
    echo "Adding SUPERSET"
    sed -i "s/#- SUPERSET/- SUPERSET/g" ~/ansible-hortonworks/playbooks/group_vars/all
fi

if has_component "KAFKA4"; then
    echo "Adding KAFKA4"
    sed -i "s/#, 'KAFKA4_CLIENT'/, 'KAFKA4_CLIENT'/g" ~/ansible-hortonworks/playbooks/group_vars/all
    sed -i "s/#- KAFKA4_MIRRORMAKER/- KAFKA4_MIRRORMAKER/g" ~/ansible-hortonworks/playbooks/group_vars/all
    sed -i "s/#- KAFKA4_BROKER/- KAFKA4_BROKER/g" ~/ansible-hortonworks/playbooks/group_vars/all
    sed -i "s/#- KAFKA4_CONNECT/- KAFKA4_CONNECT/g" ~/ansible-hortonworks/playbooks/group_vars/all
fi

if has_component "CRUISE_CONTROL4"; then
    echo "Adding CRUISE_CONTROL4"
    sed -i "s/#- CRUISE_CONTROL4/- CRUISE_CONTROL4/g" ~/ansible-hortonworks/playbooks/group_vars/all
fi

if has_component "NIFI2"; then
    echo "Adding NIFI2"
    sed -i "s/#- NIFI2_MASTER/- NIFI2_MASTER/g" ~/ansible-hortonworks/playbooks/group_vars/all
fi

if has_component "NIFI_REGISTRY2"; then
    echo "Adding NIFI REGISTRY2"
    sed -i "s/#- NIFI_REGISTRY2/- NIFI_REGISTRY2/g" ~/ansible-hortonworks/playbooks/group_vars/all
fi

if has_component "TRINO-GATEWAY"; then
    echo "Adding TRINO-GATEWAY"
    sed -i "s/#- TRINO_GATEWAY/- TRINO_GATEWAY/g" ~/ansible-hortonworks/playbooks/group_vars/all
fi

# Tokens are ODP repo dir names; clients are the mpack component names (SPARK_RAPIDS3 vs SPARK4_RAPIDS).
if has_component "SPARK-RAPIDS-355"; then
    echo "Adding SPARK-RAPIDS (Spark3)"
    sed -i "s/#, 'SPARK_RAPIDS3_CLIENT'/, 'SPARK_RAPIDS3_CLIENT'/g" ~/ansible-hortonworks/playbooks/group_vars/all
fi

if has_component "SPARK-RAPIDS-411"; then
    echo "Adding SPARK-RAPIDS (Spark4)"
    sed -i "s/#, 'SPARK4_RAPIDS_CLIENT'/, 'SPARK4_RAPIDS_CLIENT'/g" ~/ansible-hortonworks/playbooks/group_vars/all
fi

if has_component "CELEBORN"; then
    echo "Adding CELEBORN"
    sed -i "s/#, 'CELEBORN_CLIENT'/, 'CELEBORN_CLIENT'/g" ~/ansible-hortonworks/playbooks/group_vars/all
    sed -i "s/#- CELEBORN_MASTER/- CELEBORN_MASTER/g" ~/ansible-hortonworks/playbooks/group_vars/all
    sed -i "s/#- CELEBORN_WORKER/- CELEBORN_WORKER/g" ~/ansible-hortonworks/playbooks/group_vars/all
fi

if has_component "SOLR"; then
    echo "Adding SOLR"
    sed -i "s/#, 'SOLR_CLIENT'/, 'SOLR_CLIENT'/g" ~/ansible-hortonworks/playbooks/group_vars/all
    sed -i "s/#- SOLR_SERVER/- SOLR_SERVER/g" ~/ansible-hortonworks/playbooks/group_vars/all
fi

if has_component "ATLAS"; then
    echo "Adding ATLAS"
    sed -i "s/#, 'ATLAS_CLIENT'/, 'ATLAS_CLIENT'/g" ~/ansible-hortonworks/playbooks/group_vars/all
    sed -i "s/#- ATLAS_SERVER/- ATLAS_SERVER/g" ~/ansible-hortonworks/playbooks/group_vars/all
fi


sed -i "s/is_vm_docker_containers: 'no'/is_vm_docker_containers: 'yes'/g" ~/ansible-hortonworks/playbooks/group_vars/all

# Exit immediately if any command fails
set -e

source ~/ansible/bin/activate

# Run Ubuntu-specific pre-requisites if OS is Ubuntu
if [[ $OS_TYPE == "ubuntu20" || $OS_TYPE == "ubuntu22" || $OS_TYPE == "ubuntu"* ]]; then
    echo "Running Ubuntu pre-requisites playbook for $OS_TYPE..."
    cd ~/ansible-hortonworks/playbooks && export ANSIBLE_HOST_KEY_CHECKING=False && ansible-playbook -i ../inventory/static Ubuntu_pre_reqs.yml --extra-vars "odp_repo=${odpUrl} ambari_repo=${ambariUrl} odp_utils_repo=${odpUtilsUrl}"
    cd ~/
fi

cd ~/ansible-hortonworks/ && bash prepare_nodes.sh -vv
cd ~/ansible-hortonworks/ && bash install_ambari.sh -vv
cd ~/ansible-hortonworks/ && bash configure_ambari.sh -vv
cd ~/ansible-hortonworks/ && bash apply_blueprint.sh -vv

echo "Script completed."
fi
