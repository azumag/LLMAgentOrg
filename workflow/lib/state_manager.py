"""
状態管理モジュール

runs/{task-id}/state.json の読み書きを行う。
"""

from pathlib import Path
from typing import Optional, Any
import json
from datetime import datetime, timezone


class Status:
    """状態定数"""
    INIT = "INIT"
    DESIGNING = "DESIGNING"
    DESIGNED = "DESIGNED"
    IMPLEMENTING = "IMPLEMENTING"
    TESTING = "TESTING"
    RETRYING = "RETRYING"
    ESCALATING = "ESCALATING"
    REVIEWING = "REVIEWING"
    COMPLETED = "COMPLETED"
    FAILED = "FAILED"


class StateManager:
    """runs/{task-id}/state.json を管理するクラス"""

    def __init__(self, runs_dir: Path, task_id: str):
        """初期化。runs_dir/task_id/state.json を管理"""
        self.runs_dir = Path(runs_dir)
        self.task_id = task_id
        self.task_dir = self.runs_dir / task_id
        self.state_file = self.task_dir / "state.json"

    def _get_timestamp(self) -> str:
        """現在時刻をISO形式で取得"""
        return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")

    def init_state(self, max_retries: int = 3) -> dict:
        """新規タスクの状態を初期化"""
        # ディレクトリが存在しない場合は作成
        self.task_dir.mkdir(parents=True, exist_ok=True)

        timestamp = self._get_timestamp()
        state = {
            "task_id": self.task_id,
            "status": Status.INIT,
            "created_at": timestamp,
            "updated_at": timestamp,
            "steps": {
                "design": {
                    "status": "pending"
                },
                "test_cases": {
                    "status": "pending"
                },
                "implementation": {
                    "status": "pending",
                    "attempt": 0
                },
                "testing": {
                    "status": "pending",
                    "results": []
                },
                "review": {
                    "status": "pending"
                }
            },
            "escalation": {
                "count": 0,
                "history": []
            },
            "retry_count": 0,
            "max_retries": max_retries
        }
        self.save(state)
        return state

    def load(self) -> dict:
        """state.json を読み込み"""
        if not self.state_file.exists():
            return self.init_state()

        with open(self.state_file, "r", encoding="utf-8") as f:
            return json.load(f)

    def save(self, state: dict) -> None:
        """state.json を保存（updated_at を自動更新）"""
        # ディレクトリが存在しない場合は作成
        self.task_dir.mkdir(parents=True, exist_ok=True)

        state["updated_at"] = self._get_timestamp()

        with open(self.state_file, "w", encoding="utf-8") as f:
            json.dump(state, f, indent=2, ensure_ascii=False)

    def update_status(self, new_status: str) -> dict:
        """全体のステータスを更新"""
        state = self.load()
        state["status"] = new_status
        self.save(state)
        return state

    def update_step(self, step_name: str, **kwargs: Any) -> dict:
        """特定のステップを更新"""
        state = self.load()

        if step_name not in state["steps"]:
            state["steps"][step_name] = {}

        for key, value in kwargs.items():
            state["steps"][step_name][key] = value

        self.save(state)
        return state

    def increment_retry(self) -> dict:
        """リトライカウントをインクリメント"""
        state = self.load()
        state["retry_count"] = state.get("retry_count", 0) + 1
        self.save(state)
        return state

    def add_escalation(self, reason: str, response: Optional[str] = None) -> dict:
        """エスカレーション履歴を追加"""
        state = self.load()

        escalation_entry = {
            "timestamp": self._get_timestamp(),
            "reason": reason
        }
        if response is not None:
            escalation_entry["response"] = response

        state["escalation"]["count"] = state["escalation"].get("count", 0) + 1
        state["escalation"]["history"].append(escalation_entry)

        self.save(state)
        return state

    def get_current_step(self) -> str:
        """現在のステップ名を取得"""
        state = self.load()

        # ステップの順序
        step_order = ["design", "test_cases", "implementation", "testing", "review"]

        # in_progress のステップを探す
        for step_name in step_order:
            if step_name in state["steps"]:
                if state["steps"][step_name].get("status") == "in_progress":
                    return step_name

        # in_progress がなければ、最初の pending を返す
        for step_name in step_order:
            if step_name in state["steps"]:
                if state["steps"][step_name].get("status") == "pending":
                    return step_name

        # すべて completed なら最後のステップを返す
        return step_order[-1]

    def can_retry(self) -> bool:
        """リトライ可能かどうかを判定"""
        state = self.load()
        return state.get("retry_count", 0) < state.get("max_retries", 3)

    def is_completed(self) -> bool:
        """タスクが完了しているかどうかを判定"""
        state = self.load()
        return state.get("status") == Status.COMPLETED

    def is_failed(self) -> bool:
        """タスクが失敗しているかどうかを判定"""
        state = self.load()
        return state.get("status") == Status.FAILED
