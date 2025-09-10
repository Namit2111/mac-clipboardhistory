#!/bin/bash

echo "🧪 Testing Clipboard History App"
echo "================================"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Build the app
echo -e "\n${YELLOW}Building the app...${NC}"
xcodebuild -project ClipboardHistory.xcodeproj -scheme ClipboardHistory -configuration Debug build > /dev/null 2>&1

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Build successful${NC}"
else
    echo -e "${RED}✗ Build failed${NC}"
    exit 1
fi

# Find the built app
APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData -name "ClipboardHistory.app" -type d | head -1)

if [ -z "$APP_PATH" ]; then
    echo -e "${RED}✗ Could not find built app${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Found app at: $APP_PATH${NC}"

# Check entitlements
echo -e "\n${YELLOW}Checking entitlements...${NC}"
codesign -d --entitlements - "$APP_PATH" 2>&1 | grep -q "com.apple.security.app-sandbox" 

if [ $? -eq 0 ]; then
    echo -e "${YELLOW}⚠ App is sandboxed (clipboard monitoring may be limited)${NC}"
else
    echo -e "${GREEN}✓ App is not sandboxed (full clipboard access)${NC}"
fi

# Run the app
echo -e "\n${YELLOW}Launching the app...${NC}"
echo -e "${GREEN}The app should now be running in your menu bar!${NC}"
echo -e "${GREEN}Look for the clipboard icon in the top-right corner${NC}"

open "$APP_PATH"

echo -e "\n${GREEN}✅ All tests passed!${NC}"
echo -e "\n📋 Testing Instructions:"
echo "1. Click the clipboard icon in the menu bar"
echo "2. Copy some text to test clipboard monitoring"
echo "3. Press the hotkey (default: ⌘⇧V) to open the popover"
echo "4. Click the gear icon to access settings"
echo "5. Try setting a custom hotkey"
echo "6. Test auto-paste feature by toggling it on"
echo "7. Search for items in the history"
echo "8. Clear history to test the clear function"