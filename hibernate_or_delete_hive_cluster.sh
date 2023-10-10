#!/bin/bash
################################

# Hibernate / Destroy Cluster Script

################################

## Use your HIVE group namespace and Cluster name
export HIVE_GROUP_NS=rhods
export CLUSTER_NAME=ods-qe-08

## Get Cluster Pool information
oc get clusterpool -n ${HIVE_GROUP_NS} | grep ${CLUSTER_NAME}

cluster_pool=$(oc get clusterpool | grep -m1 "^${CLUSTER_NAME}" | awk '{print $1}')

## Get Pool Namespace
oc get namespace | grep ods-qe

cluster_pool_ns=$(oc get ns | grep ${cluster_pool} | awk '{print $1}')

## Get all Pods, Jobs, and ClusterDeployment (cd) in the Pool namespace
oc get job,pod,cd -n ${cluster_pool_ns}

## Get Cluster Deployment instance
cluster_deploy="$(oc get ClusterDeployment -n ${cluster_pool_ns} -o name)"

## Check cluster power status (before hibernating/resuming):
oc describe ${cluster_deploy} -n ${cluster_pool_ns} | grep "Power State" -C 5

## Hibernate your cluster now
oc patch ${cluster_deploy} -n ${cluster_pool_ns} --type='merge' -p $'spec:\n powerState: Hibernating'

## Resume the hibernated cluster
oc patch ${cluster_deploy} -n ${cluster_pool_ns} --type='merge' -p $'spec:\n powerState: Running'

## Timeout to Hibernate your cluster, for example after 8 hours
# oc patch ${cluster_deploy} -n ${cluster_pool_ns} --type='merge' -p $'spec:\n hibernateAfter: 8h'

## Timeout to Destroy your cluster, for example after 8 hours
oc patch ${cluster_deploy} -n ${cluster_pool_ns} --type='merge' -p $'spec:\n deleteAfter: 8h'

## To destroy your cluster now - Delete its Claim
oc get clusterclaim -n ${HIVE_GROUP_NS} | grep ods-qe

hive_cluster_claim=$(oc get clusterclaim -n ${HIVE_GROUP_NS} | grep -m1 "^${CLUSTER_NAME}" | awk '{print $1}')

oc delete -n ${HIVE_GROUP_NS} clusterclaim ${hive_cluster_claim}

oc logs -n ${cluster_pool_ns} -l hive.openshift.io/job-type=provision --pod-running-timeout=3m -c hive --tail=-1 -f

## Delete the cluster pool and deployment configuration
oc delete -n ${HIVE_GROUP_NS} clusterpool ${cluster_pool}

oc get clusterdeploymentcustomization -n ${HIVE_GROUP_NS} | grep ods-qe

hive_cluster_conf=$(oc get clusterdeploymentcustomization -n ${HIVE_GROUP_NS} | grep -m1 "^${CLUSTER_NAME}" | awk '{print $1}')

oc delete -n ${HIVE_GROUP_NS} clusterdeploymentcustomization ${hive_cluster_conf}
