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

    # AlarmDescription은 경보 자체에 대한 설명이라 상태와 무관하게 고정된다.
    # OK 상태에서 "ERROR가 감지되었습니다"가 그대로 나오면 오해를 주므로 상태별로 문구를 나눈다.
    if state == "ALARM":
        headline = alarm.get("AlarmDescription") or "임계값을 초과했습니다."
    elif state == "OK":
        headline = "지표가 임계값 아래로 돌아와 경보가 해제되었습니다."
    else:
        headline = "지표를 판단할 데이터가 부족합니다."

    return {
        "title": f"[{state}] {alarm.get('AlarmName', 'Unknown alarm')}",
        "description": alarm.get("NewStateReason", ""),
        "color": COLORS.get(state, 0x868E96),
        "fields": [
            {
                "name": "상태" if state == "OK" else "감지 내용",
                "value": headline,
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
    # User-Agent를 지정하지 않으면 urllib 기본값(Python-urllib/x.y)이 전송되는데,
    # Discord 앞단의 Cloudflare가 이를 차단해 403을 반환한다.
    request = urllib.request.Request(
        WEBHOOK_URL,
        data=json.dumps(payload).encode("utf-8"),
        headers={
            "Content-Type": "application/json",
            "User-Agent": "taskflow-alerts/1.0 (+https://github.com/taskflow-eks)",
        },
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
