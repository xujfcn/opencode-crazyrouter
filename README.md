# OpenCode × Crazyrouter 一键配置脚本

把 [OpenCode](https://opencode.ai) 配置为通过 [Crazyrouter](https://cn.crazyrouter.com?utm_source=github&utm_medium=tutorial&utm_campaign=opencode_crazyrouter) 使用 Claude、GPT、DeepSeek、Qwen 等模型。

> 入口要求：用户面对的入口是 `https://cn.crazyrouter.com`；OpenCode 自定义 OpenAI-compatible provider 需要 `/v1`，所以脚本会自动写入 `https://cn.crazyrouter.com/v1` 到 `provider.options.baseURL`。

## 一键使用

```bash
curl -fsSL https://raw.githubusercontent.com/xujfcn/opencode-crazyrouter/main/setup.sh | bash
```

脚本会：

- 检查 `python3`、`curl`、`opencode` 是否存在；
- 让你粘贴 Crazyrouter API Key；
- 写入 `~/.config/opencode/opencode.json`；
- 添加 `crazyrouter` 自定义 provider；
- 设置默认模型，例如 `crazyrouter/claude-sonnet-4.6`；
- 调用 `https://cn.crazyrouter.com/v1/models` 验证 API Key 和 endpoint；
- 覆盖旧配置前自动生成 `.bak.<timestamp>` 备份。

## 非交互使用

```bash
CRAZYROUTER_API_KEY=sk-your-key \
  bash <(curl -fsSL https://raw.githubusercontent.com/xujfcn/opencode-crazyrouter/main/setup.sh) \
  --yes --model claude-sonnet-4.6
```

## 配置结果

脚本会向 OpenCode 配置中写入类似内容：

```json
{
  "$schema": "https://opencode.ai/config.json",
  "provider": {
    "crazyrouter": {
      "npm": "@ai-sdk/openai-compatible",
      "name": "Crazyrouter",
      "options": {
        "baseURL": "https://cn.crazyrouter.com/v1",
        "apiKey": "YOUR_CRAZYROUTER_API_KEY",
        "timeout": 600000,
        "chunkTimeout": 30000
      },
      "models": {
        "claude-sonnet-4.6": { "name": "Claude Sonnet 4.6" },
        "claude-opus-4-8": { "name": "Claude Opus 4.8" },
        "gpt-5.5": { "name": "GPT-5.5" },
        "deepseek-v4-flash": { "name": "DeepSeek V4 Flash" },
        "qwen3-coder": { "name": "Qwen3 Coder" }
      }
    }
  },
  "model": "crazyrouter/claude-sonnet-4.6",
  "small_model": "crazyrouter/deepseek-v4-flash"
}
```

## 常用参数

```bash
./setup.sh --model claude-opus-4-8
./setup.sh --small-model deepseek-v4-flash
./setup.sh --config ./opencode.json
./setup.sh --provider-id crazyrouter
./setup.sh --no-default
./setup.sh --skip-test
```

## 启动 OpenCode

```bash
opencode
```

进入 TUI 后运行：

```text
/models
```

选择 `crazyrouter/...` 模型即可。

## 为什么不是直接写 `https://cn.crazyrouter.com`？

OpenCode 的自定义 provider 使用 `@ai-sdk/openai-compatible` 适配器。OpenAI-compatible API 的 baseURL 需要指向 `/v1`：

```text
https://cn.crazyrouter.com/v1
```

如果只是 Claude Code / Anthropic 原生客户端，才使用根域名：

```text
https://cn.crazyrouter.com
```

OpenCode 属于 OpenAI-compatible custom provider 场景，所以脚本自动把根域名规范为 `/v1` 地址。

## 链接

- Crazyrouter 控制台：https://cn.crazyrouter.com?utm_source=github&utm_medium=tutorial&utm_campaign=opencode_crazyrouter
- OpenCode Providers 文档：https://opencode.ai/docs/providers/
- OpenCode Config 文档：https://opencode.ai/docs/config/

## License

MIT
