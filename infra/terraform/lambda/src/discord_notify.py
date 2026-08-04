import json
import os
import urllib.request

WEBHOOK_URL = os.environ["DISCORD_WEBHOOK_URL"]

# CloudWatch 경보 상태별 색상 (Discord embed)
COLORS = {
    "ALARM": 0xE03131,
    "OK": 0x2F9E44,
    "INSUFFICIENT_DATA": 0xF08C00,
}


def build_embed(alarm: dict) -> dict:
    state = alarm.get("NewStateValue", "UNKNOWN")

    return {
        "title": f"[{state}] {alarm.get('AlarmName', 'Unknown alarm')}",
        "description": alarm.get("NewStateReason", ""),
        "color": COLORS.get(state, 0x868E96),
        "fields": [
            {
                "name": "설명",
                "value": alarm.get("AlarmDescription") or "-",
                "inline": False,
            },
            {
                "name": "리전",
                "value": alarm.get("Region", "-"),
                "inline": True,
            },
            {
                "name": "발생 시각",
                "value": alarm.get("StateChangeTime", "-"),
                "inline": True,
            },
        ],
    }


def post_to_discord(payload: dict) -> int:
    request = urllib.request.Request(
        WEBHOOK_URL,
        data=json.dumps(payload).encode("utf-8"),
        headers={"Content-Type": "application/json"},
        method="POST",
    )

    with urllib.request.urlopen(request, timeout=10) as response:
        return response.status


def handler(event, context):
    for record in event.get("Records", []):
        message = record["Sns"]["Message"]

        try:
            alarm = json.loads(message)
            payload = {"embeds": [build_embed(alarm)]}
        except json.JSONDecodeError:
            # CloudWatch 경보가 아닌 일반 메시지는 그대로 전달
            payload = {"content": message[:1900]}

        status = post_to_discord(payload)
        print(f"discord response status={status}")

    return {"statusCode": 200}
