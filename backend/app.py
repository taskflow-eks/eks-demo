import os
import json
import socket
import datetime
import boto3
from flask import Flask, jsonify, request
from flask_sqlalchemy import SQLAlchemy

app = Flask(__name__)


def get_db_credentials():
    """Secrets Manager에서 DB 자격증명 가져오기"""
    secret_name = os.getenv("DB_SECRET_NAME")
    if not secret_name:
        # 로컬 개발용 fallback
        return {
            "host":     os.getenv("DB_HOST", "localhost"),
            "port":     os.getenv("DB_PORT", "5432"),
            "dbname":   os.getenv("DB_NAME", "eksdb"),
            "username": os.getenv("DB_USER", "postgres"),
            "password": os.getenv("DB_PASSWORD", "password"),
        }

    client = boto3.client("secretsmanager", region_name=os.getenv("AWS_REGION", "ap-northeast-2"))
    secret = client.get_secret_value(SecretId=secret_name)
    return json.loads(secret["SecretString"])


creds = get_db_credentials()
DATABASE_URL = (
    f"postgresql://{creds['username']}:{creds['password']}"
    f"@{creds['host']}:{creds.get('port', 5432)}/{creds['dbname']}"
)

app.config["SQLALCHEMY_DATABASE_URI"] = DATABASE_URL
app.config["SQLALCHEMY_TRACK_MODIFICATIONS"] = False

db = SQLAlchemy(app)


class Task(db.Model):
    __tablename__ = "tasks"
    id    = db.Column(db.Integer, primary_key=True)
    title = db.Column(db.String(255), nullable=False)
    done  = db.Column(db.Boolean, default=False)

    def to_dict(self):
        return {"id": self.id, "title": self.title, "done": self.done}


with app.app_context():
    db.create_all()


@app.route("/")
def index():
    return jsonify({
        "message": "EKS Demo API",
        "pod":     socket.gethostname(),
        "version": os.getenv("APP_VERSION", "1.0.0"),
        "time":    datetime.datetime.utcnow().isoformat() + "Z",
    })


@app.route("/health")
def health():
    return jsonify({"status": "healthy"})


@app.route("/tasks", methods=["GET"])
def get_tasks():
    tasks = Task.query.all()
    return jsonify({"tasks": [t.to_dict() for t in tasks], "count": len(tasks)})


@app.route("/tasks", methods=["POST"])
def create_task():
    data = request.get_json()
    if not data or "title" not in data:
        return jsonify({"error": "title is required"}), 400
    task = Task(title=data["title"])
    db.session.add(task)
    db.session.commit()
    return jsonify(task.to_dict()), 201


@app.route("/tasks/<int:task_id>", methods=["PUT"])
def update_task(task_id):
    task = Task.query.get_or_404(task_id)
    data = request.get_json() or {}
    task.done  = data.get("done", task.done)
    task.title = data.get("title", task.title)
    db.session.commit()
    return jsonify(task.to_dict())


@app.route("/tasks/<int:task_id>", methods=["DELETE"])
def delete_task(task_id):
    task = Task.query.get_or_404(task_id)
    db.session.delete(task)
    db.session.commit()
    return jsonify({"message": "deleted"}), 200


if __name__ == "__main__":
    port = int(os.getenv("PORT", 5000))
    app.run(host="0.0.0.0", port=port)
