import { useEffect, useState } from "react";

const API = "/api";

export default function App() {
  const [tasks, setTasks] = useState([]);
  const [input, setInput] = useState("");
  const [info, setInfo] = useState(null);

  useEffect(() => {
    fetch(`${API}/`)
      .then((r) => r.json())
      .then(setInfo);
    loadTasks();
  }, []);

  function loadTasks() {
    fetch(`${API}/tasks`)
      .then((r) => r.json())
      .then((d) => setTasks(d.tasks));
  }

  function addTask() {
    if (!input.trim()) return;
    fetch(`${API}/tasks`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ title: input }),
    }).then(() => {
      setInput("");
      loadTasks();
    });
  }

  function toggleTask(task) {
    fetch(`${API}/tasks/${task.id}`, {
      method: "PUT",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ done: !task.done }),
    }).then(loadTasks);
  }

  function deleteTask(id) {
    fetch(`${API}/tasks/${id}`, { method: "DELETE" }).then(loadTasks);
  }

  return (
    <div style={styles.container}>
      <h1 style={styles.title}>TaskFlow</h1>

      {info && (
        <div style={styles.info}>
          <span>Pod: <b>{info.pod}</b></span>
          <span>Version: <b>{info.version}</b></span>
        </div>
      )}

      <div style={styles.inputRow}>
        <input
          style={styles.input}
          value={input}
          onChange={(e) => setInput(e.target.value)}
          onKeyDown={(e) => e.key === "Enter" && addTask()}
          placeholder="할 일 입력..."
        />
        <button style={styles.addBtn} onClick={addTask}>추가</button>
      </div>

      <ul style={styles.list}>
        {tasks.map((t) => (
          <li key={t.id} style={styles.item}>
            <span
              onClick={() => toggleTask(t)}
              style={{ ...styles.taskTitle, textDecoration: t.done ? "line-through" : "none", color: t.done ? "#aaa" : "#222", cursor: "pointer" }}
            >
              {t.done ? "✅" : "⬜"} {t.title}
            </span>
            <button style={styles.delBtn} onClick={() => deleteTask(t.id)}>삭제</button>
          </li>
        ))}
      </ul>
    </div>
  );
}

const styles = {
  container: { maxWidth: 600, margin: "60px auto", fontFamily: "sans-serif", padding: "0 16px" },
  title: { fontSize: 24, marginBottom: 8 },
  info: { display: "flex", gap: 16, fontSize: 13, color: "#555", marginBottom: 20 },
  inputRow: { display: "flex", gap: 8, marginBottom: 24 },
  input: { flex: 1, padding: "8px 12px", fontSize: 16, border: "1px solid #ccc", borderRadius: 6 },
  addBtn: { padding: "8px 16px", background: "#2563eb", color: "#fff", border: "none", borderRadius: 6, cursor: "pointer", fontSize: 15 },
  list: { listStyle: "none", padding: 0, margin: 0 },
  item: { display: "flex", justifyContent: "space-between", alignItems: "center", padding: "10px 0", borderBottom: "1px solid #eee" },
  taskTitle: { flex: 1 },
  delBtn: { padding: "4px 10px", background: "#ef4444", color: "#fff", border: "none", borderRadius: 4, cursor: "pointer" },
};
