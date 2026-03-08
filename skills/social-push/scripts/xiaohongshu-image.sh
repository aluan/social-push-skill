#!/bin/bash
# 小红书图文发布脚本
# Usage: ./xiaohongshu-image.sh <图片路径> <标题> <正文内容> [话题] [发布动作]

set -e

# 参数检查
if [ $# -lt 3 ]; then
    echo "Usage: $0 <图片路径> <标题> <正文内容> [话题] [发布动作]"
    echo "Example: $0 /path/to/image.jpg '我的标题' '这是正文内容' '生活分享' 'publish'"
    echo ""
    echo "发布动作："
    echo "  draft   - 保存草稿（默认）"
    echo "  publish - 立即发布"
    exit 1
fi

IMAGE_PATH="$1"
TITLE="$2"
CONTENT="$3"
TOPIC="${4:-}"
ACTION="${5:-draft}"

# 检查标题长度
TITLE_LENGTH=${#TITLE}
if [ $TITLE_LENGTH -gt 20 ]; then
    echo "警告：标题长度为 $TITLE_LENGTH 字符，超过建议的 20 字符限制"
    read -p "是否继续？(y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# 检查图片文件是否存在
if [ ! -f "$IMAGE_PATH" ]; then
    echo "错误：图片文件不存在: $IMAGE_PATH"
    exit 1
fi

echo "=== 小红书图文发布流程 ==="
echo "图片: $IMAGE_PATH"
echo "标题: $TITLE"
echo "正文: $CONTENT"
[ -n "$TOPIC" ] && echo "话题: $TOPIC"
echo ""

# 1. 打开发布图文的网站
echo "步骤 1: 打开小红书创作者平台..."
agent-browser --headed --profile /tmp/agent-profile open "https://creator.xiaohongshu.com/publish/publish?source=official&from=tab_switch&target=image"

# 等待页面加载
agent-browser wait --load networkidle

# 2. 查看交互并提取上传按��
echo "步骤 2: 查看页面交互元素..."
agent-browser snapshot -i > /tmp/xhs_snapshot.txt 2>&1
UPLOAD_REF=$(grep -i 'Choose File\|上传图片\|upload' /tmp/xhs_snapshot.txt | head -1 | sed -n 's/.*\[ref=\(e[0-9]*\)\].*/\1/p')
if [ -z "$UPLOAD_REF" ]; then
    echo "错误：无法找到上传按钮"
    exit 1
fi

# 3. 上传图片
echo "步骤 3: 上传图片..."
agent-browser upload "@$UPLOAD_REF" "$IMAGE_PATH"

# 等待上传完成
agent-browser wait --load networkidle

# 4. 查看交互并提取标题输入框
echo "步骤 4: 查看编辑页面..."
agent-browser snapshot -i > /tmp/xhs_snapshot.txt 2>&1
TITLE_REF=$(grep 'textbox ".*标题.*"' /tmp/xhs_snapshot.txt | head -1 | sed -n 's/.*\[ref=\(e[0-9]*\)\].*/\1/p')
if [ -z "$TITLE_REF" ]; then
    echo "错误：无法找到标题输入框"
    exit 1
fi

# 5. 插入标题
echo "步骤 5: 填写标题..."
agent-browser fill "@$TITLE_REF" "$TITLE"

# 6. 插入正文
echo "步骤 6: 填写正文..."
agent-browser fill ".ProseMirror" "$CONTENT"

# 7. 添加话题（如果提供）
if [ -n "$TOPIC" ]; then
    echo "步骤 7: 添加话题..."
    agent-browser type ".ProseMirror" " #$TOPIC"
    agent-browser press "Enter"
fi

# 8. 提取发布按钮
echo "步骤 8: 准备发布选项..."
agent-browser snapshot -i > /tmp/xhs_snapshot.txt 2>&1
DRAFT_BUTTON_REF=$(grep "button \"暂存离开\"" /tmp/xhs_snapshot.txt | head -1 | sed -n 's/.*\[ref=\(e[0-9]*\)\].*/\1/p')
PUBLISH_BUTTON_REF=$(grep "button \"发布\"" /tmp/xhs_snapshot.txt | head -1 | sed -n 's/.*\[ref=\(e[0-9]*\)\].*/\1/p')

# 9. 最后一步：根据参数自动执行或询问用户
echo ""
echo "=== 发布选项 ==="

if [[ "$ACTION" == "publish" ]]; then
    echo "自动发布模式：立即发布..."
    agent-browser click "@$PUBLISH_BUTTON_REF"
    # 等待发布完成
    agent-browser wait --load networkidle
    echo "✓ 发布成功"
elif [[ "$ACTION" == "draft" ]]; then
    echo "自动草稿模式：暂存草稿..."
    agent-browser click "@$DRAFT_BUTTON_REF"
    agent-browser wait --load networkidle
    echo "✓ 已保存为草稿"
fi

echo ""
echo "=== 完成 ==="
