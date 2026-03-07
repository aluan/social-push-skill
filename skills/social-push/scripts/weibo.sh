#!/bin/bash
# 微博发布脚本
# Usage: ./weibo.sh <内容> [图片路径] [话题] [操作]

set -e

# 参数检查
if [ $# -lt 1 ]; then
    echo "Usage: $0 <内容> [图片路径] [话题] [操作]"
    echo "Example: $0 '今天天气真好' /path/to/image.jpg '生活记录' publish"
    echo ""
    echo "注意：普通用户字数限制 140 字，会员 2000 字"
    echo ""
    echo "操作选项："
    echo "  skip    - 不发布，保留内容（默认）"
    echo "  publish - 立即发送"
    exit 1
fi

CONTENT="$1"
IMAGE_PATH="${2:-}"
TOPIC="${3:-}"
ACTION="${4:-skip}"

# 检查图片文件（如果提供）
if [ -n "$IMAGE_PATH" ] && [ ! -f "$IMAGE_PATH" ]; then
    echo "错误：图片文件不存在: $IMAGE_PATH"
    exit 1
fi

# 检查字数
CONTENT_LENGTH=${#CONTENT}
if [ $CONTENT_LENGTH -gt 140 ]; then
    echo "警告：内容长度为 $CONTENT_LENGTH 字，超过普通用户 140 字限制（会员 2000 字）"
fi

echo "=== 微博发布流程 ==="
echo "内容: $CONTENT"
[ -n "$IMAGE_PATH" ] && echo "图片: $IMAGE_PATH"
[ -n "$TOPIC" ] && echo "话题: $TOPIC"
echo ""

# 1. 打开微博主页
echo "步骤 1: 打开微博..."
agent-browser --headed --profile /tmp/agent-profile open "https://weibo.com"
sleep 3

# 2. 检测是否需要登录
agent-browser snapshot -i > /tmp/weibo_snapshot.txt 2>&1
if grep -qi 'visitor\|登录\|login' /tmp/weibo_snapshot.txt; then
    echo ""
    echo ">>> 检测到未登录，请在浏览器中完成微博登录"
    read -p "    登录完成后按 Enter 继续..."
    sleep 2
fi

# 3. 查看交互并提取内容输入框
echo "步骤 3: 查看页面交互元素..."
agent-browser snapshot -i > /tmp/weibo_snapshot.txt 2>&1
CONTENT_REF=$(grep -i '有什么新鲜事\|新鲜事想分享' /tmp/weibo_snapshot.txt | head -1 | sed -n 's/.*\[ref=\(e[0-9]*\)\].*/\1/p')
if [ -z "$CONTENT_REF" ]; then
    echo "错误：无法找到内容输入框"
    exit 1
fi

# 4. 填写内容
echo "步骤 4: 填写微博内容..."
agent-browser fill "@$CONTENT_REF" "$CONTENT"

# 5. 添加话题（如果提供）
if [ -n "$TOPIC" ]; then
    echo "步骤 5: 添加话题..."
    agent-browser type "@$CONTENT_REF" " #${TOPIC}#"
fi

# 6. 上传图片（如果提供）
if [ -n "$IMAGE_PATH" ]; then
    echo "步骤 6: 上传图片..."
    agent-browser upload "input[type='file']" "$IMAGE_PATH"
    sleep 2
fi

# 7. 提取发布按钮
echo "步骤 7: 准备发布..."
agent-browser snapshot -i > /tmp/weibo_snapshot.txt 2>&1
PUBLISH_REF=$(grep 'button "发送\|button "发布' /tmp/weibo_snapshot.txt | head -1 | sed -n 's/.*\[ref=\(e[0-9]*\)\].*/\1/p')
if [ -z "$PUBLISH_REF" ]; then
    echo "错误：无法找到发送按钮"
    exit 1
fi

# 8. 最后一步：根据参数执行操作
echo ""
if [[ "$ACTION" == "publish" ]]; then
    echo "发送微博..."
    agent-browser click "@$PUBLISH_REF"
    echo "✓ 发送成功"
else
    echo "已取消发布，内容保留在编辑框中"
fi

echo ""
echo "=== 完成 ==="
