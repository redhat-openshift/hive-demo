#!/bin/bash
################################

# Create Cluster Script

################################

## Connect to Hive with the Kubeconfig you received from Hive team

export HIVE_KUBCONF=./kubeconf_hive_rhods
chmod 444 ${HIVE_KUBCONF} # Read only is recommended
export KUBECONFIG=${HIVE_KUBCONF}

## Use template files for Hive configuration, in order to inject variables in it for the cluster deployment
export HIVE_CLUSTER_TEMPLATE=./hive_psi_rhods_template.yaml
export HIVE_CLAIM_TEMPLATE=./hive_claim_template.yaml

## The HIVE_CLUSTER_TEMPLATE
cat "$HIVE_CLUSTER_TEMPLATE"

## The namespace of your Hive group
export HIVE_GROUP_NS=rhods

## Set your cluster name with lowercase only and '-' (not '_')
export CLUSTER_NAME=ods-qe-08

## Main Hive resources that controls the cluster deployment
export HIVE_CLUSTER_CLAIM=${CLUSTER_NAME}-claim
export HIVE_CLUSTER_POOL=${CLUSTER_NAME}-pool
export HIVE_CLUSTER_CONF=${CLUSTER_NAME}-conf

## List Hive cluster Claims - Where we'll add new ${CLUSTER_NAME}-claim

oc get -n ${HIVE_GROUP_NS} clusterclaim | grep ods-qe

## List Hive cluster Pools - Where we'll add new ${CLUSTER_NAME}-pool

oc get -n ${HIVE_GROUP_NS} clusterpool | grep ods-qe

## List Hive cluster Deployment customizations - Where we'll add new ${CLUSTER_NAME}-conf

oc get -n ${HIVE_GROUP_NS} clusterdeploymentcustomization | grep ods-qe

## Openshift version and instances type to install

export OCP_VERSION=4.13.5
export INSTANCE_TYPE=g.standard.xxl

## Of course you can set more Openshift variables like Networks, Nodes, etc.

## Configure access to Openstack (PSI) where Hive will provision the cluster

## Set the OpenStack clouds.yaml to access PSI
export OSP_CRED_YAML=./clouds.yaml

## Set the PSI Cloud (e.g. openstack / rhos-d / rhos-01)
export OS_CLOUD=rhos-01

## Set the PSI Network (as available on the specific PSI Cloud)
export OSP_NETWORK=shared_net_6

## Encode clouds.yaml - To be added in the Hive template
export OSP_CRED_ENCODED="$(base64 -w0 "$OSP_CRED_YAML")"
export OSP_CLOUD_ENCODED="$(echo -n "openstack" | base64 -w0)"

## Connect to the PSI cloud
openstack --os-cloud "${OS_CLOUD}" token issue

## Configure access to AWS to setup DNS records for the cluster

aws configure set aws_access_key_id "$AWS_KEY"
aws configure set aws_secret_access_key "$AWS_SECRET"
aws sts get-caller-identity

## Create local directory for cluster configurations, logs and credentials
export CLUSTER_DIR=./${CLUSTER_NAME}_setup
mkdir -p ${CLUSTER_DIR}
export HIVE_CLUSTER_YAML=${CLUSTER_DIR}/${CLUSTER_NAME}_hive_deploy.yaml
export HIVE_CLAIM_YAML=${CLUSTER_DIR}/${CLUSTER_NAME}_hive_claim.yaml
export HIVE_INSTALL_LOGS=${CLUSTER_DIR}/${CLUSTER_NAME}_install.log

## Create Openstack Floating IPs and assign them in AWS DNS

bash "./create_fips.sh" "${CLUSTER_NAME}" "${AWS_DOMAIN}" "${OSP_NETWORK}" "${OS_CLOUD}" "${CLUSTER_DIR}"

## The Floating IPs must be set, to be used for Cluster API and APPS endpoints
. ./${CLUSTER_DIR}/*.fips

## Create the Hive configuration yaml, by injecting variables to ${HIVE_CLUSTER_TEMPLATE}

envsubst < ${HIVE_CLUSTER_TEMPLATE} > ${HIVE_CLUSTER_YAML}

cat ${HIVE_CLUSTER_YAML}

oc apply -f ${HIVE_CLUSTER_YAML}

## Create the Hive Claim yaml, by injecting variables to ${HIVE_CLAIM_YAML}

envsubst < ${HIVE_CLAIM_TEMPLATE} > ${HIVE_CLAIM_YAML}

cat ${HIVE_CLAIM_YAML}

oc apply -f ${HIVE_CLAIM_YAML}

## Check if Hive Claim initiated
oc describe -n ${HIVE_GROUP_NS} clusterclaim ${HIVE_CLUSTER_CLAIM}

## Check if Hive Pool initiated
oc describe -n ${HIVE_GROUP_NS} clusterpool ${HIVE_CLUSTER_POOL}

## Check if Hive Deployment initiated
oc describe -n ${HIVE_GROUP_NS} clusterdeploymentcustomization ${HIVE_CLUSTER_CONF}

## Get cluster Pool Namespace - Where the cluster deployment job is running in
cluster_pool="$(oc get clusterclaim ${HIVE_CLUSTER_CLAIM} -o jsonpath='{.spec.clusterPoolName}')"

oc get ns | grep ${cluster_pool}

cluster_pool_ns=$(oc get ns | grep ${cluster_pool} | awk '{print $1}')

## Get all Pods, Jobs, and ClusterDeployment (cd) in the Pool namespace
oc get job,pod,cd -n ${cluster_pool_ns}

## Watch cluster installation inside the Hive container:

oc logs -n ${cluster_pool_ns} -l hive.openshift.io/job-type=provision --pod-running-timeout=3m -c hive --tail=-1 -f
