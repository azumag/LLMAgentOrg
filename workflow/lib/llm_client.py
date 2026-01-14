"""
LLM Client Module - Unified interface for calling various LLMs.

Supports:
- Claude (via claude CLI)
- Gemini (via gemini CLI)
- LFM (via llama-server HTTP API)
"""

from pathlib import Path
from typing import Optional
import subprocess
import json
import urllib.request
import urllib.error


class LLMError(Exception):
    """LLM invocation error."""
    pass


class LLMClient:
    """Unified interface for LLM invocation."""

    # Default configurations for each LLM type
    DEFAULT_CONFIGS = {
        "claude": {
            "command": ["claude", "-p"],
            "args": ["--print"],
            "timeout": 120,
        },
        "gemini": {
            "command": ["gemini", "-p"],
            "args": [],
            "timeout": 120,
        },
        "lfm": {
            "url": "http://localhost:8080/v1/chat/completions",
            "model": "LFM2.5-1.2B-Instruct",
            "temperature": 0.7,
            "max_tokens": 4096,
            "timeout": 60,
        },
    }

    SUPPORTED_TYPES = ["claude", "gemini", "lfm"]

    def __init__(self, llm_type: str, config: Optional[dict] = None):
        """
        Initialize LLM client.

        Args:
            llm_type: "claude" | "gemini" | "lfm"
            config: Configuration dictionary (optional, uses defaults if not provided)

        Raises:
            ValueError: If llm_type is not supported
        """
        if llm_type not in self.SUPPORTED_TYPES:
            raise ValueError(
                f"Unsupported LLM type: {llm_type}. "
                f"Supported types: {', '.join(self.SUPPORTED_TYPES)}"
            )

        self.llm_type = llm_type
        self.config = {**self.DEFAULT_CONFIGS[llm_type], **(config or {})}

    def invoke(
        self,
        prompt: str,
        system: Optional[str] = None,
        timeout: Optional[int] = None
    ) -> str:
        """
        Invoke LLM and get response.

        Args:
            prompt: User prompt
            system: System prompt (optional)
            timeout: Timeout in seconds (optional, uses config default)

        Returns:
            Response string from LLM

        Raises:
            LLMError: When LLM invocation fails
        """
        effective_timeout = timeout or self.config.get("timeout")

        if self.llm_type == "claude":
            return self._invoke_claude(prompt, system, effective_timeout)
        elif self.llm_type == "gemini":
            return self._invoke_gemini(prompt, system, effective_timeout)
        elif self.llm_type == "lfm":
            return self._invoke_lfm(prompt, system, effective_timeout)
        else:
            raise LLMError(f"Unknown LLM type: {self.llm_type}")

    def invoke_with_files(
        self,
        prompt: str,
        context_files: list[Path],
        system: Optional[str] = None,
        timeout: Optional[int] = None
    ) -> str:
        """
        Invoke LLM with file contents as context.

        Args:
            prompt: User prompt
            context_files: List of files to include as context
            system: System prompt (optional)
            timeout: Timeout in seconds (optional)

        Returns:
            Response string from LLM

        Raises:
            LLMError: When LLM invocation fails or file reading fails
        """
        # Build context from files
        context_parts = []
        for file_path in context_files:
            path = Path(file_path)
            if not path.exists():
                raise LLMError(f"Context file not found: {path}")

            try:
                content = path.read_text(encoding="utf-8")
                context_parts.append(
                    f"--- File: {path.name} ---\n{content}\n--- End of {path.name} ---"
                )
            except Exception as e:
                raise LLMError(f"Failed to read file {path}: {e}")

        # Combine context with prompt
        if context_parts:
            full_prompt = (
                "Context files:\n\n"
                + "\n\n".join(context_parts)
                + f"\n\nUser request:\n{prompt}"
            )
        else:
            full_prompt = prompt

        return self.invoke(full_prompt, system=system, timeout=timeout)

    def _invoke_claude(
        self,
        prompt: str,
        system: Optional[str],
        timeout: int
    ) -> str:
        """Invoke Claude via CLI."""
        command = list(self.config["command"])

        # Add system prompt if provided
        if system:
            prompt = f"System: {system}\n\nUser: {prompt}"

        command.append(prompt)
        command.extend(self.config.get("args", []))

        try:
            result = subprocess.run(
                command,
                capture_output=True,
                text=True,
                timeout=timeout
            )

            if result.returncode != 0:
                error_msg = result.stderr.strip() if result.stderr else "Unknown error"
                raise LLMError(f"Claude CLI failed: {error_msg}")

            return result.stdout.strip()

        except subprocess.TimeoutExpired:
            raise LLMError(f"Claude CLI timed out after {timeout} seconds")
        except FileNotFoundError:
            raise LLMError("Claude CLI not found. Is 'claude' installed and in PATH?")
        except Exception as e:
            raise LLMError(f"Failed to invoke Claude: {e}")

    def _invoke_gemini(
        self,
        prompt: str,
        system: Optional[str],
        timeout: int
    ) -> str:
        """Invoke Gemini via CLI."""
        command = list(self.config["command"])

        # Add system prompt if provided
        if system:
            prompt = f"System: {system}\n\nUser: {prompt}"

        command.append(prompt)
        command.extend(self.config.get("args", []))

        try:
            result = subprocess.run(
                command,
                capture_output=True,
                text=True,
                timeout=timeout
            )

            if result.returncode != 0:
                error_msg = result.stderr.strip() if result.stderr else "Unknown error"
                raise LLMError(f"Gemini CLI failed: {error_msg}")

            return result.stdout.strip()

        except subprocess.TimeoutExpired:
            raise LLMError(f"Gemini CLI timed out after {timeout} seconds")
        except FileNotFoundError:
            raise LLMError("Gemini CLI not found. Is 'gemini' installed and in PATH?")
        except Exception as e:
            raise LLMError(f"Failed to invoke Gemini: {e}")

    def _invoke_lfm(
        self,
        prompt: str,
        system: Optional[str],
        timeout: int
    ) -> str:
        """Invoke LFM via llama-server HTTP API."""
        url = self.config["url"]

        # Build messages
        messages = []
        if system:
            messages.append({"role": "system", "content": system})
        messages.append({"role": "user", "content": prompt})

        data = {
            "model": self.config["model"],
            "messages": messages,
            "temperature": self.config["temperature"],
            "max_tokens": self.config["max_tokens"],
        }

        try:
            req = urllib.request.Request(
                url,
                data=json.dumps(data).encode("utf-8"),
                headers={"Content-Type": "application/json"}
            )

            response = urllib.request.urlopen(req, timeout=timeout)
            result = json.loads(response.read().decode("utf-8"))

            return result["choices"][0]["message"]["content"]

        except urllib.error.URLError as e:
            raise LLMError(
                f"Failed to connect to LFM server at {url}: {e}. "
                "Is llama-server running?"
            )
        except urllib.error.HTTPError as e:
            raise LLMError(f"LFM server returned HTTP error {e.code}: {e.reason}")
        except json.JSONDecodeError as e:
            raise LLMError(f"Failed to parse LFM response: {e}")
        except KeyError:
            raise LLMError("Unexpected response format from LFM server")
        except TimeoutError:
            raise LLMError(f"LFM request timed out after {timeout} seconds")
        except Exception as e:
            raise LLMError(f"Failed to invoke LFM: {e}")


# Convenience factory functions
def create_claude_client(config: Optional[dict] = None) -> LLMClient:
    """Create a Claude LLM client."""
    return LLMClient("claude", config)


def create_gemini_client(config: Optional[dict] = None) -> LLMClient:
    """Create a Gemini LLM client."""
    return LLMClient("gemini", config)


def create_lfm_client(config: Optional[dict] = None) -> LLMClient:
    """Create a LFM (llama-server) LLM client."""
    return LLMClient("lfm", config)


# Usage example
if __name__ == "__main__":
    # Example usage
    print("LLM Client Module")
    print("=" * 40)
    print(f"Supported LLM types: {', '.join(LLMClient.SUPPORTED_TYPES)}")
    print()
    print("Example usage:")
    print('  client = LLMClient("claude")')
    print('  response = client.invoke("Hello, world!")')
    print()
    print("With system prompt:")
    print('  response = client.invoke("Explain AI", system="You are a teacher")')
    print()
    print("With files:")
    print('  response = client.invoke_with_files("Review this", [Path("code.py")])')
