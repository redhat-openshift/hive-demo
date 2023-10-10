#!/bin/bash
################################

# Collect logs and Credentials Script

################################

export CLUSTER_NAME=ods-qe-08
export CLUSTER_DIR=./${CLUSTER_NAME}_setup
export HIVE_INSTALL_LOGS=${CLUSTER_DIR}/${CLUSTER_NAME}_install.log

export HIVE_CLUSTER_CLAIM=${CLUSTER_NAME}-claim
cluster_pool="$(oc get clusterclaim ${HIVE_CLUSTER_CLAIM} -o jsonpath='{.spec.clusterPoolName}')"

oc get ns | grep ${cluster_pool}

cluster_pool_ns=$(oc get ns | grep ${cluster_pool} | awk '{print $1}')

## Collect all Cluster install logs from the Pool namespace
oc logs -n ${cluster_pool_ns} -l hive.openshift.io/job-type=provision --all-containers --tail=-1 > "${HIVE_INSTALL_LOGS}"

## Save Cluster admin user password to file

oc extract -n ${cluster_pool_ns} secret/$(oc -n ${cluster_pool_ns} get cd ${cluster_pool_ns} -o jsonpath='{.spec.clusterMetadata.adminPasswordSecretRef.name}') --to=${CLUSTER_DIR} --confirm

## Save Cluster Kubeconfig file

oc extract -n ${cluster_pool_ns} secret/$(oc -n ${cluster_pool_ns} get cd ${cluster_pool_ns} -o jsonpath='{.spec.clusterMetadata.adminKubeconfigSecretRef.name}') --to=${CLUSTER_DIR} --confirm

## All Hive configuration and cluster details created in ${CLUSTER_DIR}
ls -l ${CLUSTER_DIR}

## Print Cluster Web Console
oc -n ${cluster_pool_ns} get cd ${cluster_pool_ns} -o jsonpath='{ .status.webConsoleURL }'
