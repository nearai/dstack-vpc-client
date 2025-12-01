#!/bin/sh
set -e

apk add --no-cache jq

echo 'Fetching instance info from dstack-mesh...'
echo 'wget -qO- $DSTACK_MESH_URL/info'
INFO=$(wget -qO- $DSTACK_MESH_URL/info)
INSTANCE_ID=$(echo '$INFO' | jq -r .instance_id)
echo 'INSTANCE_ID: $INSTANCE_ID'
echo 'VPC Server App ID: $VPC_SERVER_APP_ID'

RESPONSE=$(wget -qO- --header='x-dstack-target-app: $VPC_SERVER_APP_ID' --header='Host: vpc-server' ' DSTACK_MESH_URL/api/register?instance_id=$INSTANCE_ID&node_name=$NODE_NAME')

PRE_AUTH_KEY=$(echo '$RESPONSE' | jq -r .pre_auth_key)
VPC_SERVER_URL=$(echo '$RESPONSE' | jq -r .server_url)

if [ -z '$PRE_AUTH_KEY' ] || [ -z '$VPC_SERVER_URL' ]; then
	echo 'Error: Missing required fields in response'
	echo 'Response: $RESPONSE'
	exit 1
fi
echo 'VPC setup completed'

echo 'Starting Tailscale with:'
echo '  Server: $VPC_SERVER_URL'
echo '  Hostname: $NODE_NAME'

tailscaled --tun=$TUN_DEV_NAME --state=/var/lib/tailscale/tailscaled.state --socket=/var/run/tailscale/tailscaled.sock &
sleep 3

tailscale up \
	--login-server='$VPC_SERVER_URL' \
	--authkey='$PRE_AUTH_KEY' \
	--hostname='$NODE_NAME' \
	--reset \
	--accept-dns

echo 'Tailscale connected successfully'

# Start status updater
echo 'Starting status updater (interval: 30s)...'

while true; do
	tailscale status --json > /shared/tailscale_status.json 2>/dev/null || echo 'Failed to get status' > /shared/tailscale_status.json
	echo 'Status updated'
	sleep 30
done