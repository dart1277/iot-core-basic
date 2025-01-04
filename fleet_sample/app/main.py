import ssl
import time
import json
import paho.mqtt.client as mqtt

# Configuration
AWS_IOT_ENDPOINT = "a2ux6zzpisl7iq-ats.iot.us-east-1.amazonaws.com"  # Replace with your AWS IoT Core endpoint
PROVISIONING_CERT_PATH = "prov_cert.pem"  # Path to the provisioning certificate
PROVISIONING_KEY_PATH = "prov_private_key.pem"  # Path to the private key
ROOT_CA_PATH = "AmazonRootCA1.pem"  # Path to the root CA certificate
DEVICE_SERIAL_NUMBER = "DEVTHINGID123456"  # Replace with your device's serial number

# AWS IoT topics for fleet provisioning
CREATE_KEYS_AND_CERTIFICATE_TOPIC = "$aws/certificates/create/json"
CREATE_KEYS_AND_CERTIFICATE_RESPONSE_TOPIC = "$aws/certificates/create/json/accepted"
CREATE_KEYS_AND_CERTIFICATE_RESPONSE_REJECTED_TOPIC = (
    "$aws/certificates/create/json/rejected"
)
FLEET_PROVISIONING_REQUEST_TOPIC = (
    "$aws/provisioning-templates/MyProvisioningTemplate/provision/json"
)
FLEET_PROVISIONING_RESPONSE_TOPIC = (
    "$aws/provisioning-templates/MyProvisioningTemplate/provision/json/accepted"
)
FLEET_PROVISIONING_RESPONSE_REJECTED_TOPIC = (
    "$aws/provisioning-templates/MyProvisioningTemplate/provision/json/rejected"
)

#         "parameters": {
#     "DeviceSerialNumber": DEVICE_SERIAL_NUMBER,
#     "AWS::IoT::Certificate::Id": CERTIFICATE_ID,
# }


## Global variables to store responses
# create_keys_response = None
# provisioning_response = None


# def on_create_keys_response(client, userdata, message):
#     """Callback to handle CreateKeysAndCertificate response."""
#     global create_keys_response
#     print("Received CreateKeysAndCertificate response:")
#     print(message.payload.decode())
#     create_keys_response = json.loads(message.payload.decode())


# def on_provisioning_response(client, userdata, message):
#     """Callback to handle provisioning response."""
#     global provisioning_response
#     print("Received provisioning response:")
#     print(message.payload.decode())
#     provisioning_response = json.loads(message.payload.decode())


# def initialize_mqtt_client(client_id):
#     """Initialize the MQTT client."""
#     client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION1, client_id=client_id)
#     client.tls_set(
#         ca_certs=ROOT_CA_PATH,
#         certfile=PROVISIONING_CERT_PATH,
#         keyfile=PROVISIONING_KEY_PATH,
#         cert_reqs=ssl.CERT_REQUIRED,
#         tls_version=ssl.PROTOCOL_TLSv1_2,
#         ciphers=None,
#     )
#     # client.tls_insecure_set(False)
#     return client


# def main():
#     global create_keys_response, provisioning_response

#     # Initialize MQTT client
#     mqtt_client = initialize_mqtt_client(DEVICE_SERIAL_NUMBER)
#     mqtt_client.connect(AWS_IOT_ENDPOINT, port=8883)
#     mqtt_client.loop_start()
#     print("Connected to AWS IoT Core")

#     # Step 1: Create Keys and Certificate
#     print("Requesting keys and certificate...")
#     mqtt_client.subscribe(CREATE_KEYS_AND_CERTIFICATE_RESPONSE_TOPIC)
#     mqtt_client.message_callback_add(
#         CREATE_KEYS_AND_CERTIFICATE_RESPONSE_TOPIC, on_create_keys_response
#     )
#     mqtt_client.message_callback_add(
#         CREATE_KEYS_AND_CERTIFICATE_RESPONSE_REJECTED_TOPIC, on_create_keys_response
#     )
#     mqtt_client.publish(CREATE_KEYS_AND_CERTIFICATE_TOPIC, json.dumps({}), qos=1)

#     # Wait for CreateKeysAndCertificate response
#     timeout = 180
#     while create_keys_response is None and timeout > 0:
#         time.sleep(1)
#         timeout -= 1

#     if create_keys_response is None:
#         print("CreateKeysAndCertificate response not received. Exiting.")
#         mqtt_client.loop_stop()
#         mqtt_client.disconnect()
#         return

#     # Extract the certificateOwnershipToken and key-pair
#     certificate_ownership_token = create_keys_response["certificateOwnershipToken"]
#     device_cert = create_keys_response["certificatePem"]
#     private_key = create_keys_response["privateKey"]
#     certificateId = create_keys_response["certificateId"]

#     print("Keys and certificate created successfully!")
#     print(f"Certificate Ownership Token: {certificate_ownership_token}")
#     print("Saving keys and certificate...")

#     # Save the new certificate and private key
#     with open("device_certificate.pem", "w") as cert_file:
#         cert_file.write(device_cert)

#     with open("device_private_key.pem", "w") as key_file:
#         key_file.write(private_key)

#     # Step 2: Register Thing
#     print("Registering the device with AWS IoT...")
#     mqtt_client.subscribe(FLEET_PROVISIONING_RESPONSE_TOPIC)
#     mqtt_client.message_callback_add(
#         FLEET_PROVISIONING_RESPONSE_TOPIC, on_provisioning_response
#     )

#     provisioning_payload = {
#         "certificateOwnershipToken": certificate_ownership_token,
#         "parameters": {
#             "DeviceSerialNumber": DEVICE_SERIAL_NUMBER,
#             "AWS::IoT::Certificate::Id": certificateId,
#         },
#     }
#     mqtt_client.publish(
#         FLEET_PROVISIONING_REQUEST_TOPIC, json.dumps(provisioning_payload), qos=1
#     )

#     # Wait for provisioning response
#     timeout = 180
#     while provisioning_response is None and timeout > 0:
#         time.sleep(1)
#         timeout -= 1

#     if provisioning_response is None:
#         print("Provisioning response not received. Exiting.")
#         mqtt_client.loop_stop()
#         mqtt_client.disconnect()
#         return

#     # Extract thing information
#     thing_name = provisioning_response["thingName"]

#     print("Device provisioned successfully!")
#     print(f"Thing Name: {thing_name}")

#     # Disconnect MQTT client
#     mqtt_client.loop_stop()
#     mqtt_client.disconnect()
#     print("Device successfully provisioned and MQTT client disconnected.")


# if __name__ == "__main__":
#     main()


def on_connect(client, userdata, flags, rc, properties):
    if rc == 0:
        print("Connected to IoT Core successfully.")
        # Publish a message to the specified topic
        client.subscribe(CREATE_KEYS_AND_CERTIFICATE_RESPONSE_TOPIC, qos=1)
        client.subscribe(CREATE_KEYS_AND_CERTIFICATE_RESPONSE_REJECTED_TOPIC, qos=1)
        client.subscribe(FLEET_PROVISIONING_RESPONSE_TOPIC, qos=1)
        client.subscribe(FLEET_PROVISIONING_RESPONSE_REJECTED_TOPIC, qos=1)
        client.publish(CREATE_KEYS_AND_CERTIFICATE_TOPIC, "{}", qos=1)
        print(f"Published create certs message")
    else:
        print(f"Connection failed with result code {rc}.")

def on_disconnect(client, userdata, rc, properties):
    print(f"Disconnected with result code {rc}.")

def on_message(client, userdata, msg):
    print(f"Received message on topic {msg.topic}: {msg.payload.decode()}")
    if msg.topic == "$aws/certificates/create/json/accepted":
        create_keys_response = json.loads(msg.payload.decode())
        certificate_ownership_token = create_keys_response["certificateOwnershipToken"]
        device_cert = create_keys_response["certificatePem"]
        private_key = create_keys_response["privateKey"]
        certificateId = create_keys_response["certificateId"]

        print("Keys and certificate created successfully!")
        print(f"Certificate Ownership Token: {certificate_ownership_token}")
        print("Saving keys and certificate...")
        # Save the new certificate and private key
        with open("device_certificate.pem", "w") as cert_file:
            cert_file.write(device_cert)

        with open("device_private_key.pem", "w") as key_file:
            key_file.write(private_key)

        # Step 2: Register Thing
        print("Registering the device with AWS IoT...")
        provisioning_payload = {
            "certificateOwnershipToken": certificate_ownership_token,
            "parameters": {
                "DeviceSerialNumber": DEVICE_SERIAL_NUMBER,
                "AWS::IoT::Certificate::Id": certificateId,
            },
        }
        client.publish(
            FLEET_PROVISIONING_REQUEST_TOPIC, json.dumps(provisioning_payload), qos=1
        )

# Create an MQTT client instance
client = mqtt.Client(client_id=DEVICE_SERIAL_NUMBER, protocol=mqtt.MQTTv5)

# Configure TLS
client.tls_set(
    ca_certs=ROOT_CA_PATH,
    certfile=PROVISIONING_CERT_PATH,
    keyfile=PROVISIONING_KEY_PATH,
    cert_reqs=ssl.CERT_REQUIRED,
    tls_version=ssl.PROTOCOL_TLSv1_2,
    ciphers=None
)
client.tls_insecure_set(False)

# Set the MQTT callbacks
client.on_connect = on_connect
client.on_disconnect = on_disconnect
client.on_message = on_message


# Connect to the AWS IoT Core broker
print("Connecting to AWS IoT Core...")
client.connect(AWS_IOT_ENDPOINT, port=8883)


# Start the MQTT network loop to handle connection and communication
try:
    client.loop_forever()
except KeyboardInterrupt:
    print("Disconnecting...")
    client.disconnect()
