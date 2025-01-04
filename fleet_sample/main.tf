# Note:
# 1. Remember to download AWS root CA pem file (can create a dummy certificate from console, and then download)

# 2.
# security profiles can be created to perform actions on devices on conditions
# for ex. can enforce packet limit for a device
# see AWS IoT > Security > Detect > Security profiles

provider "aws" {
  region = "us-east-1" # Change this to your desired AWS region
}

# Create an IoT Thing Group
resource "aws_iot_thing_group" "device_fleet" {
  name = "MyDeviceFleet"
}

# resource "aws_iot_thing_type" "device_fleet" { # requires 5 min to delete
#   name = "MyDeviceFleetType"
# }
# thing config with type looks like:
# "thing": {
#     "Type": "AWS::IoT::Thing",
#     "Properties": {
#         "ThingName": {
#             "Fn::Join": [
#                 "",
#                 [
#                     "Device-",
#                     {
#                         "Ref": "DeviceSerialNumber"
#                     }
#                 ]
#             ]
#         },
#         "AttributePayload": {
#             "version": "v1",
#             "serialNumber": {
#                 "Ref": "DeviceSerialNumber"
#             }
#         },
#         "ThingGroups": [
#             "${aws_iot_thing_group.device_fleet.name}"
#         ],
#         "ThingTypeName": "${aws_iot_thing_type.device_fleet.name}"
#     },
#     "OverrideSettings": {
#         "AttributePayload": "MERGE",
#         "ThingTypeName": "REPLACE",
#         "ThingGroups": "DO_NOTHING"
#     }
# },


data "aws_iam_policy_document" "device_policy" {
  statement {
    sid    = "DeviceFleetPolicy1"
    effect = "Allow"

    resources = [
      "arn:aws:iot:*:*:topic/*",
      "arn:aws:iot:*:*:client/*",
    ]

    actions = [
      "iot:Connect",
      "iot:Publish",
      "iot:Subscribe",
      "iot:Receive",
    ]
  }

  statement {
    sid       = ""
    effect    = "Allow"
    resources = ["arn:aws:iot:*:*:thing/*"]

    actions = [
      "iot:GetThingShadow",
      "iot:UpdateThingShadow",
    ]
  }
}


# Create an IoT Policy for provisioned devices
resource "aws_iot_policy" "device_policy" {
  name   = "MyDevicePolicy"
  policy = data.aws_iam_policy_document.device_policy.json
}

# Create a provisioning template
resource "aws_iot_provisioning_template" "device_provisioning_template" {
  name        = "MyProvisioningTemplate"
  description = "Provisioning template for my IoT devices"

  enabled = true

  provisioning_role_arn = aws_iam_role.provisioning_role.arn

  template_body = <<TEMPLATE
{
    "Parameters": {
        "DeviceSerialNumber": {
            "Type": "String"
        },
      "AWS::IoT::Certificate::Id":{
         "Type":"String"
      }
    },
    "Resources": {
        "thing": {
            "Type": "AWS::IoT::Thing",
            "Properties": {
                "ThingName": {
                    "Fn::Join": [
                        "",
                        [
                            "Device-",
                            {
                                "Ref": "DeviceSerialNumber"
                            }
                        ]
                    ]
                },
                "AttributePayload": {
                    "version": "v1",
                    "serialNumber": {
                        "Ref": "DeviceSerialNumber"
                    }
                },
                "ThingGroups": [
                    "${aws_iot_thing_group.device_fleet.name}"
                ]
            },
            "OverrideSettings": {
                "AttributePayload": "MERGE",
                "ThingTypeName": "REPLACE",
                "ThingGroups": "DO_NOTHING"
            }
        },
      "certificate":{
         "Type":"AWS::IoT::Certificate",
         "Properties":{
            "CertificateId":{
               "Ref":"AWS::IoT::Certificate::Id"
            },
          "Status":"ACTIVE"
         }
      },
        "policy": {
            "Type": "AWS::IoT::Policy",
            "Properties": {
                "PolicyDocument": ${data.aws_iam_policy_document.device_policy.json}
            }
        }
    }
}
TEMPLATE
}

## template could also use previously created policy:
# "PolicyName": "CommonFleetPolicy",
#  Policy resources must define one property: PolicyName or PolicyDocument

# Create an IAM Role for provisioning
resource "aws_iam_role" "provisioning_role" {
  name = "IoTProvisioningRole"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "iot.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

# Attach permissions to the provisioning role
resource "aws_iam_policy" "provisioning_policy" {
  name = "IoTProvisioningPolicy"

  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "iot:CreateThing",
        "iot:DescribeThing*",
        "iot:AddThingToThingGroup",
        "iot:AttachPolicy",
        "iot:AttachThingPrincipal",
        "iot:CreateCertificateFromCsr",
        "iot:CreateKeysAndCertificate",
        "iot:RegisterThing",
        "iot:ListThingGroupsForThing",
        "iot:DescribeCertificate",
        "iot:CreatePolicy",
        "iot:AttachPrincipalPolicy",
        "iot:UpdateCertificate"
      ],
      "Resource": "*"
    }
  ]
}
POLICY
}


# API calls during certificate creation:


# CreateCertificateFromCsr

# CreateKeysAndCertificate

# RegisterThing


resource "aws_iam_role_policy_attachment" "provisioning_policy_attachment" {
  role       = aws_iam_role.provisioning_role.name
  policy_arn = aws_iam_policy.provisioning_policy.arn
}

# Create an initial provisioning certificate
resource "aws_iot_certificate" "provisioning_certificate" {
  active = true
}

resource "aws_iot_policy" "iot_policy" {
  name = "MyIoTPolicyFleet"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = ["iot:Connect", "iot:Publish", "iot:Subscribe", "iot:Receive"],
        # Action   = ["iot:Connect", "iot:Publish", "iot:Subscribe", "iot:Receive"],
        Resource = "*"
      }
    ]
  })
}

# tighten the policy
# {
#     "Version": "2012-10-17",
#     "Statement": [
#         {
#             "Effect": "Allow",
#             "Action": ["iot:Connect"],
#             "Resource": "*"
#         },
#         {
#             "Effect": "Allow",
#             "Action": ["iot:Publish","iot:Receive"],
#             "Resource": [
#                 "arn:aws:iot:aws-region:aws-account-id:topic/$aws/certificates/create/*",
#                 "arn:aws:iot:aws-region:aws-account-id:topic/$aws/provisioning-templates/templateName/provision/*"
#             ]
#         },
#         {
#             "Effect": "Allow",
#             "Action": "iot:Subscribe",
#             "Resource": [
#                 "arn:aws:iot:aws-region:aws-account-id:topicfilter/$aws/certificates/create/*",
#                 "arn:aws:iot:aws-region:aws-account-id:topicfilter/$aws/provisioning-templates/templateName/provision/*"
#             ]
#         }
#     ]
# }


resource "aws_iot_policy_attachment" "policy_attachment" {
  policy = aws_iot_policy.iot_policy.name
  target = aws_iot_certificate.provisioning_certificate.arn
}

resource "local_file" "cert" {
  content  = aws_iot_certificate.provisioning_certificate.certificate_pem
  filename = "prov_cert.pem"
}

resource "local_file" "private_key" {
  content  = aws_iot_certificate.provisioning_certificate.private_key
  filename = "prov_private_key.pem"
}

output "provisioning_certificate_pem" {
  value     = aws_iot_certificate.provisioning_certificate.certificate_pem
  sensitive = true
}

output "provisioning_certificate_private_key" {
  value     = aws_iot_certificate.provisioning_certificate.private_key
  sensitive = true
}

output "provisioning_certificate_arn" {
  value = aws_iot_certificate.provisioning_certificate.arn
}

data "aws_iot_endpoint" "iot_endpoint" {
  endpoint_type = "iot:Data-ATS"
}

output "aws_iot_endpoint" {
  value = data.aws_iot_endpoint.iot_endpoint
}
