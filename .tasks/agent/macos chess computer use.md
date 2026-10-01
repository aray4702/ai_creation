# Desktop GUI Automation: macOS Chess Computer Use

Execute native desktop GUI automation to play against the macOS default Chess application.

## Task Prompt
"我已经打开了 Mac 自带的游戏（Chess），请不要考虑胜负，以最快的速度下棋。"

## Agent Execution Requirements
- **Target Application**: macOS Native Chess (`/System/Applications/Chess.app`).
- **Optimization Priority**: Speed-first execution over deep engine calculation.
- **Action Cycle**:
  1. Capture real-time visual screen frame.
  2. Detect player move / board state update.
  3. Compute immediate valid piece gesture coordinates.
  4. Perform immediate hardware mouse drag-and-drop to make the corresponding move.
- **Target Pace**: Complete a standard 20-turn match in under 5 minutes without getting stuck in thinking loops.