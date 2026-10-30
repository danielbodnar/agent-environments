# 1Password secret references for bin/with-secrets --env-file.
#
# Each value is an op:// reference: op://<vault>/<item>/<field>. The vault
# comes from OP_VAULT so the real vault name never lands in this repo.
# Item and field names are examples; rename them to match your items.
#
# Use with:
#   OP_VAULT=<vault> with-secrets --env-file env/.env.tpl -- <command>

CLOUDFLARE_API_TOKEN=op://${OP_VAULT}/cloudflare/credential
CLOUDFLARE_ACCOUNT_ID=op://${OP_VAULT}/cloudflare/account-id
SOCKET_API_KEY=op://${OP_VAULT}/socket/credential
VLT_TOKEN=op://${OP_VAULT}/vlt/credential
ANTHROPIC_API_KEY=op://${OP_VAULT}/anthropic/credential
