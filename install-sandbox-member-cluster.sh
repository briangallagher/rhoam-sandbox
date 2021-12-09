#!/usr/bin/env bash

set -x

function oc::wait::object::availability() {
    local cmd=$1 # Command whose output we require
    local interval=$2 # How many seconds to sleep between tries
    local iterations=$3 # How many times we attempt to run the command

    ii=0

    while [ $ii -le $iterations ]
    do

        token=$($cmd) && returncode=$? || returncode=$?
        if [ $returncode -eq 0 ]; then
            break
        fi

        ((ii=ii+1))
        if [ $ii -eq 100 ]; then
            echo $cmd "did not return a value"
            exit 1
        fi
        sleep $interval
    done
}

CLUSTER=$1

# Pre-req: Add new folder to sandbox-sre and configure

# Step 1: Create the latest version of the Binary 
sudo make install

# Step 2: # Ensure logged into cluster
# Apply the config:
# Where -c defines the environment config to be used - is the same as the name of the directory.
# If you want to use different kubeconfig than the default one, then specify it using -k parameter

# In a brand-new cluster, the first setup command will create only a subset of the admin config since there are still missing the Toolchain CRDs.
sandbox-cli adm setup -c "bg-byoc.gzkc.s1.devshift.org" -y
sleep 2

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # 
# Step 3: 
# Copy the generated sandbox config file
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # 
cp out/config/rhoam-sb/sandbox.yaml ~/.sandbox.yaml
sleep 2



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # 
# Step 4: Install the sandbox host operator
# # # # # # # # # # # # # # # # # # # # # # # # # # # # #  
sandbox-cli adm install -t host sandbox -c "bg-byoc.gzkc.s1.devshift.org" -y
# wait for toolchain-host-operator to complete installation
oc::wait::object::availability "oc get deployment -n toolchain-host-operator host-operator-controller-manager" 10 600
oc wait -n toolchain-host-operator --for=condition=Available deployment/host-operator-controller-manager
sleep 10


# # # # # # # # # # # # # # # # # # # # # # # # # # # # # 
# Step 5: Install the sandbox member operator
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # 
sandbox-cli adm install -t member1 sandbox -c "bg-byoc.gzkc.s1.devshift.org" -y
# wait for toolchain-member-operator to complete installation
oc::wait::object::availability "oc get deployment -n toolchain-member-operator member-operator-controller-manager" 10 600
oc wait -n toolchain-member-operator --for=condition=Available deployment/member-operator-controller-manager
oc::wait::object::availability "oc get deployment -n toolchain-member-operator member-operator-webhook" 10 600
oc wait -n toolchain-member-operator --for=condition=Available deployment/member-operator-webhook
oc::wait::object::availability "oc get deployment -n toolchain-member-operator autoscaling-buffer" 10 600
oc wait -n toolchain-member-operator --for=condition=Available deployment/autoscaling-buffer
sleep 10


# # # # # # # # # # # # # # # # # # # # # # # # # # # # # 
# Step 6: Run the setup again to create the rest of the admin configs
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # 
sandbox-cli adm setup -c "bg-byoc.gzkc.s1.devshift.org" -y
sleep 2

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # 
# Step 7: Copy the newly generated sandbox config file
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # 
cp out/config/rhoam-sb/sandbox.yaml ~/.sandbox.yaml
sleep 2

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # 
# Step 8: Register the sandbox member operator:
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # 
sandbox-cli adm register-member member1 -y

sudo make install

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Sets the configure from here: resources/<environment-name-directory>/configure/host/sandbox/
# sandbox-cli adm configure -t host sandbox -y
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
sandbox-cli adm configure -t host sandbox -c "bg-byoc.gzkc.s1.devshift.org" -y

oc wait -n toolchain-host-operator --for=condition=Available deployment/registration-service
oc::wait::object::availability "oc get deployment -n toolchain-host-operator registration-service" 10 600
sleep 10

sandbox-cli adm restart -t host host-operator-controller-manager -y
sandbox-cli adm restart -t host registration-service -y
oc wait -n toolchain-host-operator --for=condition=Available deployment/host-operator-controller-manager
oc wait -n toolchain-host-operator --for=condition=Available deployment/registration-service


# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Sets the config from here: resources/<environment-name-directory>/configure/member/sandbox/
#sandbox-cli adm configure -t member1 sandbox -y
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

# The Secret toolchain-member-operator/member-operator-secret has been created
# Please go to this link to configure the actual values of the secret if needed:
# https://console-openshift-console.apps.bg.8fkd.s1.devshift.org/k8s/ns/toolchain-member-operator/secrets/member-operator-secret
sandbox-cli adm configure -t member1 sandbox -c "bg-byoc.gzkc.s1.devshift.org" -y


# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Install and configure host Prometheus 
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
sandbox-cli adm install -t host prometheus -c "bg-byoc.gzkc.s1.devshift.org" -y
oc::wait::object::availability "oc get deployment -n openshift-customer-monitoring prometheus-operator" 10 600
oc wait -n openshift-customer-monitoring --for=condition=Available deployment/prometheus-operator
sleep 10
sandbox-cli adm configure -t host prometheus -c "bg-byoc.gzkc.s1.devshift.org" -y


# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Install and configure member Prometheus 
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
sandbox-cli adm install -t member1 prometheus -c "bg-byoc.gzkc.s1.devshift.org" -y
oc::wait::object::availability "oc get deployment -n openshift-customer-monitoring prometheus-operator" 10 600
oc wait -n openshift-customer-monitoring --for=condition=Available deployment/prometheus-operator
sleep 10
sandbox-cli adm configure -t member1 prometheus -c "bg-byoc.gzkc.s1.devshift.org" -y

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Configure host Grafana
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
sandbox-cli adm configure -t host grafana -c "bg-byoc.gzkc.s1.devshift.org" -y




