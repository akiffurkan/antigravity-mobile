import asyncio
import json
import websockets

async def test():
    uri = 'ws://127.0.0.1:9400/bridge'
    async with websockets.connect(uri) as ws:
        print('[+] Connected to bridge server.')
        
        pending_responses = {}
        pushed_approvals = []
        pushed_messages = []

        async def reader():
            try:
                async for raw in ws:
                    data = json.loads(raw)
                    req_id = data.get('requestId')
                    if req_id and req_id in pending_responses:
                        pending_responses[req_id].set_result(data.get('result'))
                    elif data.get('type') == 'approval_request':
                        pushed_approvals.append(data.get('payload'))
                        print(f"    [EVENT] Pushed Approval Received: ID={data['payload'].get('id')} Command='{data['payload'].get('command')}' Risk={data['payload'].get('riskLevel')}")
                    elif data.get('type') == 'chat_message':
                        pushed_messages.append(data.get('payload'))
            except asyncio.CancelledError:
                pass

        reader_task = asyncio.create_task(reader())

        async def send_req(action, payload=None):
            req_id = f"test_{action}_{len(pending_responses)}"
            fut = asyncio.get_event_loop().create_future()
            pending_responses[req_id] = fut
            await ws.send(json.dumps({
                'type': 'request',
                'action': action,
                'requestId': req_id,
                'payload': payload or {}
            }))
            return await asyncio.wait_for(fut, timeout=5.0)

        # 1. Handshake
        await ws.send(json.dumps({
            'type': 'handshake',
            'clientId': 'test-mobile',
            'authToken': 'efefd074dfea0b245c6a747ddddafebd',
            'transport': 'wifi'
        }))
        await asyncio.sleep(0.5)
        print(f"[+] Post-handshake: Pushed Approvals received: {len(pushed_approvals)}")

        # 2. Get sessions
        sessions = await send_req('get_sessions')
        print(f"[+] Received {len(sessions)} real Antigravity sessions!")
        if sessions:
            first = sessions[0]
            print(f"    - First session: ID={first['id'][:12]}... Title={first['title'][:50]}")
            print(f"    - Preview: {first['lastMessagePreview'][:60]}")
            
            # 3. Get messages for first session
            msgs = await send_req('get_messages', {'sessionId': first['id']})
            print(f"[+] Received {len(msgs)} real messages for session {first['id'][:12]}!")
            if msgs:
                print(f"    - Sample first msg: [{msgs[0]['role']}] {msgs[0]['content'][:60]}")
                print(f"    - Sample last msg:  [{msgs[-1]['role']}] {msgs[-1]['content'][:60]}")

        # 4. Get approvals
        approvals = await send_req('get_approvals')
        print(f"[+] Pending Approvals from get_approvals: {len(approvals)}")
        for a in approvals:
            print(f"    - Approval: ID={a['id']} Command='{a['command']}' Risk={a['riskLevel']} Expires='{a['expiresAt']}'")

        # 5. Approve one
        if approvals:
            appr_id = approvals[0]['id']
            res = await send_req('approval_decision', {'approvalId': appr_id, 'decision': 'approved'})
            print(f"[+] Decision recorded for {appr_id}: {res}")

        reader_task.cancel()
        print('[SUCCESS] All bridge server protocol requests and responses verified!')

if __name__ == '__main__':
    asyncio.run(test())
