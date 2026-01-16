#!/bin/bash

# 增加 iOS project.pbxproj 中的 FLUTTER_BUILD_NUMBER

PBXPROJ_FILE="ios/Runner.xcodeproj/project.pbxproj"

# 检查文件是否存在
if [ ! -f "$PBXPROJ_FILE" ]; then
    echo "❌ 错误: 找不到文件 $PBXPROJ_FILE"
    exit 1
fi

# 获取当前的 build number (取第一个匹配的值)
CURRENT_BUILD_NUMBER=$(grep -m1 'FLUTTER_BUILD_NUMBER = ' "$PBXPROJ_FILE" | sed 's/.*FLUTTER_BUILD_NUMBER = \([0-9]*\);.*/\1/')

if [ -z "$CURRENT_BUILD_NUMBER" ]; then
    echo "❌ 错误: 无法找到 FLUTTER_BUILD_NUMBER"
    exit 1
fi

# 计算新的 build number
NEW_BUILD_NUMBER=$((CURRENT_BUILD_NUMBER + 1))

# 替换所有的 FLUTTER_BUILD_NUMBER
sed -i '' "s/FLUTTER_BUILD_NUMBER = $CURRENT_BUILD_NUMBER;/FLUTTER_BUILD_NUMBER = $NEW_BUILD_NUMBER;/g" "$PBXPROJ_FILE"

echo "✅ FLUTTER_BUILD_NUMBER 已从 $CURRENT_BUILD_NUMBER 增加到 $NEW_BUILD_NUMBER"

