# OpenCode Configuration for LLMAgentOrg

## Agent Behavior

OpenCodeはtmuxを利用して画面を分割し、分割した先のペーンでgeminiを起動し、send-keys を使って相談事を送り、指示を得てください。

Geminiに対しての相談事は、Geminiにもsend-keysを使ってopencodeに回答を送るようにまず指示してから行うこと。
