---
name: social-push-skill
description: 使用 agent-browser 帮用户将内容发到社交媒体上。当用户需要发布内容、推送文章、上传文章、发帖到社交平台时使用此 skill。
license: MIT
metadata:
  author: aluan
  version: 0.1.3
  requires:
    - agent-browser
---

用户输入 $ARGUMENTS

# social-push-skill Skill
你需要使用 bash 运行自动化脚本，帮助用户将文章、图片上传到对应的社交平台上

# Rules
1. 优先使用 scripts 目录下的自动化脚本（如果存在）
2. 如果没有对应的脚本，则参考 references 中对应平台的 workflow，使用 agent-browser 逐步执行
3. 脚本会自动处理浏览器打开、登录检查、内容填充等步骤
4. 脚本执行失败时，查看错误信息并根据 references 中的 workflow 进行调试

# Core Workflow
1. 确认发布信息 调用 AskUserQuestion tool：目标平台（小红书、微博、微信公众号）、内容类型、内容来源（文件路径/直接输入/ai 创作）、标题、话题标签
2. 检查 scripts 目录是否有对应平台的自动化脚本
3. 如果有脚本，直接调用脚本并传入参数
4. 如果没有脚本，读取 references 中对应平台的 workflow，使用 agent-browser 逐步执行


# Self-evolution

## fix and verify Workflow
网页交互可能发生变化，脚本或 workflow 可能失效，按以下步骤修复：
1. 运行 `agent-browser snapshot` 查看当前页面的详细元素
2. 对比 workflow 中的元素 ref 和当前页面的元素 ref，找到失效的步骤
3. 当查找失败，运行 `agent-browser eval "js"` 查看具体 html 元素
4. 验证正确的交互路径后：
   - 如果有对应的脚本，编辑 scripts 目录下的脚本文件
   - 如果没有脚本，编辑 references 目录下的 workflow 文件


# References

## 小红书
- **脚本**: [xiaohongshu-image.sh](./scripts/xiaohongshu-image.sh) - 图文发布自动化脚本
  - 用法: `./scripts/xiaohongshu-image.sh <图片路径> <标题> <正文内容> [话题] [发布动作]`
  - 发布动作: `publish` 立即发布（默认）, `draft` 保存草稿
- **脚本**: [xiaohongshu-article.sh](./scripts/xiaohongshu-article.sh) - 长文发布自动化脚本
  - 用法: `./scripts/xiaohongshu-article.sh <文件路径> <标题> <简介> [话题] [模版风格] [发布动作] [原创声明]`
  - 发布动作: `publish` 立即发布（默认）, `draft` 保存草稿
  - 原创声明: `true` 声明原创（默认）, `false` 不声明
- **参考**: [小红书图文](./references/小红书图文.md) - 图文发布 workflow（用于调试）
- **参考**: [小红书长文](./references/小红书长文.md) - 长文发布 workflow（用于调试）

## 微博 (Weibo)
- **脚本**: [weibo.sh](./scripts/weibo.sh) - 微博发布自动化脚本
  - 用法: `./scripts/weibo.sh <内容> <图片路径(可选)> <视频路径(可选)> [发布动作]`
  - 发布动作: `publish` 立即发布, `skip` 跳过发布（默认）
- **参考**: [微博](./references/微博.md) - 微博发布 workflow（用于调试）

## 微信公众号
- **脚本**: [weixin-article.sh](./scripts/weixin-article.sh) - 公众号文章发布自动化脚本
  - 用法: `./scripts/weixin-article.sh <文件路径> <标题> [作者] [封面图片路径] [发布动作]`
  - 发布动作: `draft` 保存草稿（默认）, `publish` 立即发布
- **参考**: [微信公众号文章](./references/微信公众号文章.md) - 公众号文章发布 workflow（用于调试）
