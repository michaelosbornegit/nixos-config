import json
import os
import sys

BEGIN = "# >>> vercel ai-gateway (nix-managed) >>>"
END = "# <<< vercel ai-gateway (nix-managed) <<<"
CODEX_BASE_URL = "https://ai-gateway.vercel.sh/codex/v1"
CLAUDE_ENV = {
    "ANTHROPIC_BASE_URL": "https://ai-gateway.vercel.sh/claude-code",
    "ANTHROPIC_API_KEY": "",
    "CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY": "1",
}
# WebSearch is a server-side tool only Anthropic's first-party API implements,
# so deny it while the gateway is enabled to keep it out of the model's context.
CLAUDE_DENY_TOOLS = ["WebSearch"]


def log(msg):
    sys.stderr.write("vercel-ai-gateway: " + msg + "\n")


def read_text(path):
    if not os.path.exists(path):
        return None
    with open(path, "r", encoding="utf-8") as handle:
        return handle.read()


def read_lines(path):
    text = read_text(path)
    if text is None:
        return []
    return text.splitlines()


def write_text_preserving_newline(path, text):
    original = read_text(path)
    if original is not None and not original.endswith("\n") and text.endswith("\n"):
        text = text[:-1]
    with open(path, "w", encoding="utf-8") as handle:
        handle.write(text)


def write_lines(path, lines):
    while lines and not lines[-1].strip():
        lines.pop()
    text = "\n".join(lines)
    if text:
        text += "\n"
    write_text_preserving_newline(path, text)


def strip_managed_block(lines):
    kept = []
    skipping = False
    for line in lines:
        stripped = line.strip()
        if stripped == BEGIN:
            skipping = True
        elif stripped == END:
            skipping = False
        elif not skipping:
            kept.append(line)
    return kept


def top_level_model_provider(lines):
    for line in lines:
        stripped = line.strip()
        if not stripped or stripped.startswith("#") or stripped.startswith("["):
            continue
        if "=" in stripped:
            name, _, value = stripped.partition("=")
            if name.strip() == "model_provider":
                return value.strip().strip("\"")
    return None


def is_vercel_provider_line(line):
    stripped = line.strip()
    if stripped.startswith("#") or stripped.startswith("["):
        return False
    if "=" not in stripped:
        return False
    name, _, value = stripped.partition("=")
    return name.strip() == "model_provider" and value.strip().strip("\"") == "vercel"


def enable_codex(path):
    lines = strip_managed_block(read_lines(path))
    if top_level_model_provider(lines) is None:
        insert_at = next(
            (i for i, line in enumerate(lines) if line.strip().startswith("[")),
            len(lines),
        )
        while insert_at > 0 and not lines[insert_at - 1].strip():
            insert_at -= 1
        lines[insert_at:insert_at] = ["model_provider = \"vercel\""]
    if not any(line.strip() == "[model_providers.vercel]" for line in lines):
        lines.extend(
            [
                "",
                BEGIN,
                "[model_providers.vercel]",
                "name = \"Vercel AI Gateway\"",
                "base_url = \"" + CODEX_BASE_URL + "\"",
                "env_key = \"AI_GATEWAY_API_KEY\"",
                "wire_api = \"responses\"",
                END,
            ]
        )
    write_lines(path, lines)


def disable_codex(path):
    if not os.path.exists(path):
        return
    lines = strip_managed_block(read_lines(path))
    lines = [line for line in lines if not is_vercel_provider_line(line)]
    write_lines(path, lines)


def load_json(path):
    text = read_text(path)
    if text is None:
        return {}
    return json.loads(text)


def save_json(path, data):
    write_text_preserving_newline(path, json.dumps(data, indent=2) + "\n")


def enable_claude(path):
    data = load_json(path)
    if not isinstance(data, dict):
        raise SystemExit("vercel-ai-gateway: " + path + " is not a JSON object; refusing to modify it")
    env = data.get("env")
    if not isinstance(env, dict):
        env = {}
        data["env"] = env
    for key in sorted(CLAUDE_ENV):
        env[key] = CLAUDE_ENV[key]
    permissions = data.get("permissions")
    if not isinstance(permissions, dict):
        permissions = {}
        data["permissions"] = permissions
    deny = permissions.get("deny")
    if not isinstance(deny, list):
        deny = []
        permissions["deny"] = deny
    for tool in CLAUDE_DENY_TOOLS:
        if tool not in deny:
            deny.append(tool)
    save_json(path, data)


def disable_claude(path):
    if not os.path.exists(path):
        return
    data = load_json(path)
    if not isinstance(data, dict):
        return
    env = data.get("env")
    if isinstance(env, dict):
        for key in list(CLAUDE_ENV):
            env.pop(key, None)
        if not env:
            data.pop("env", None)
    permissions = data.get("permissions")
    if isinstance(permissions, dict):
        deny = permissions.get("deny")
        if isinstance(deny, list):
            permissions["deny"] = [tool for tool in deny if tool not in CLAUDE_DENY_TOOLS]
            if not permissions["deny"]:
                permissions.pop("deny", None)
        if not permissions:
            data.pop("permissions", None)
    save_json(path, data)
    save_json(path, data)


def main(argv):
    if len(argv) != 4:
        raise SystemExit("usage: patch.py --enable|--disable <codex-config> <claude-settings>")
    mode, codex_path, claude_path = argv[1], argv[2], argv[3]
    if mode == "--enable":
        enable_codex(codex_path)
        enable_claude(claude_path)
        log("Codex and Claude Code configs now point at the AI Gateway.")
    elif mode == "--disable":
        disable_codex(codex_path)
        disable_claude(claude_path)
        log("AI Gateway blocks removed from Codex and Claude Code configs.")
    else:
        raise SystemExit("usage: patch.py --enable|--disable <codex-config> <claude-settings>")


main(sys.argv)
