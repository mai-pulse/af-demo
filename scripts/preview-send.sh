# usage: bash send.sh <sessionId> <mode: bundle|api> "utterance"
if [ "$2" = "bundle" ]; then T="--authoring-bundle KAN4_Order_Lookup_Agent"; else T="--api-name KAN4_Order_Lookup_Agent"; fi
echo "### USER: $3"
sf agent preview send --session-id "$1" $T -u "$3" --target-org salesforce-4qfx4y --json 2>&1 | python3 -c "
import json,sys
raw=sys.stdin.read()
try:
  d=json.loads(raw); r=d.get('result',{})
  for m in r.get('messages',[]): print('AGENT:',m.get('message'))
  if d.get('status')!=0: print(raw[:800])
except Exception: print(raw[:800])"
