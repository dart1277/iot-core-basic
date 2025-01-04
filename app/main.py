import json
import threading
import time
import paho.mqtt.client as mqtt
import ssl

# Configuration
iot_endpoint = "a2ux6zzpisl7iq-ats.iot.us-east-1.amazonaws.com"  # Replace with your IoT Core endpoint (e.g., abc12345xyz-ats.iot.us-east-1.amazonaws.com)
client_id = "MyIoTThing"  # Replace with your IoT Thing name
cert_file = "cert.pem"  # Path to your IoT Core certificate file
key_file = "private_key.pem"  # Path to your IoT Core private key file
ca_file = "AmazonRootCA1.pem"  # Path to the Amazon Root CA file (download from AWS IoT)
topic = "/data/in/test1"  # Replace with the topic you want to publish to
message = "Hello, IoT Core!"  # Replace with your message


def to_message_body(msg_text:str):
    d = {"thing": client_id, "message": msg_text}
    return json.dumps(d, indent=2, default=str)


# Define callback functions
def on_connect(client, userdata, flags, rc, properties):
    if rc == 0:
        print("Connected to IoT Core successfully.")
        # Publish a message to the specified topic
        client.subscribe(topic, qos=1)
        client.publish(topic, to_message_body(message), qos=1)
        print(f"Published message: {message} to topic: {topic}")
    else:
        print(f"Connection failed with result code {rc}.")

def on_disconnect(client, userdata, rc, properties):
    print(f"Disconnected with result code {rc}.")

def on_message(client, userdata, msg):
    print(f"Received message on topic {msg.topic}: {msg.payload.decode()}")

# Create an MQTT client instance
client = mqtt.Client(client_id=client_id, protocol=mqtt.MQTTv5)

# Configure TLS
client.tls_set(
    ca_certs=ca_file,
    certfile=cert_file,
    keyfile=key_file,
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
client.connect(iot_endpoint, port=8883)

run = True

def thread_fun(msg_pref: str):
    i = 0
    while i < 100:
        print(f'Thread loop {i}')
        if  client.is_connected():
            msg = f'{msg_pref} msg {i}'
            print(f'Publish {msg}')
            client.publish(topic, to_message_body(msg), qos=1)
        time.sleep(2)
        i = i + 1
        if run is False:
            break
    print('Thread exited')

thread = threading.Thread(target=thread_fun,  args=('Client 1',))
thread.start()

# Start the MQTT network loop to handle connection and communication
try:
    client.loop_forever()
except KeyboardInterrupt:
    print("Disconnecting...")
    run = False
    thread.join()
    client.disconnect()
