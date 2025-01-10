#!/bin/bash

THING_NAME='MyTestDevice1'
POLICY_NAME='DevCliTestThingPolicy1'

aws iot create-thing --thing-name "$THING_NAME"

CERT_ARN=$(aws iot create-keys-and-certificate \
--set-as-active \
--certificate-pem-outfile "device.pem.crt" \
--public-key-outfile "public.pem.key" \
--private-key-outfile "private.pem.key" \
--output json | jq -r '.certificateArn')

aws iot create-policy \
--policy-name "$POLICY_NAME" \
--policy-document "file://dev_cli_test_thing_policy.json"

aws iot attach-policy \
--policy-name "$POLICY_NAME" \
--target "$CERT_ARN"

aws iot attach-thing-principal \
--thing-name "$THING_NAME" \
--principal "$CERT_ARN"


aws iot list-thing-principals --thing-name "$THING_NAME"
aws iot list-attached-policies --target "$CERT_ARN"

aws iot describe-endpoint --endpoint-type iot:Data-ATS --output json | jq -r '.endpointAddress'