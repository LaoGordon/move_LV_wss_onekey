#!/bin/bash

###############################################################################
# FAST-LIVO 一键启动脚本 (修复版)
###############################################################################

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
LOG_DIR="$SCRIPT_DIR/logs"
mkdir -p "$LOG_DIR"

echo "=========================================="
echo "  FAST-LIVO 系统启动"
echo "=========================================="

# 核心修改说明：
# 1. 使用 --command="bash -c '...'" 的格式
# 2. 内部路径使用了转义引号 \"$VAR\" 以防路径带空格
# 3. 结尾使用 read 等待用户按键

gnome-terminal --window \
    --tab --title="Livox Driver" --command="bash -c '
        echo \"启动 Livox Driver...\";
        cd \"$SCRIPT_DIR/livox_ws\";
        source install/setup.bash;
        ros2 launch livox_ros_driver2 msg_MID360_launch.py 2>&1 | tee \"$LOG_DIR/livox_driver.log\";
        echo \"进程已结束，按回车退出\"; read
    '" \
    --tab --title="RealSense Camera" --command="bash -c '
        echo \"启动 RealSense...\";
        cd \"$SCRIPT_DIR\";
        source /opt/ros/humble/setup.bash;
        ros2 launch realsense2_camera rs_launch.py rgb_camera.profile:=640x480x30 align_depth.enable:=false 2>&1 | tee \"$LOG_DIR/realsense.log\";
        echo \"进程已结束，按回车退出\"; read
    '" \
    --tab --title="FAST-LIVO" --command="bash -c '
        echo \"启动 FAST-LIVO...\";
        sleep 2; 
        cd \"$SCRIPT_DIR\";
        source /opt/ros/humble/setup.bash;
        source \"$SCRIPT_DIR/livox_ws/install/setup.bash\";
        source \"$SCRIPT_DIR/fastlivo2_ws/install/setup.bash\";
        ros2 launch fast_livo mapping_mid360.launch.py 2>&1 | tee \"$LOG_DIR/fastlivo.log\";
        echo \"进程已结束，按回车退出\"; read
    '"

echo ""
echo "=========================================="
echo "所有节点启动指令已发送。"
echo "=========================================="
echo "标签1: Livox Driver   日志: $LOG_DIR/livox_driver.log"
echo "标签2: RealSense Camera 日志: $LOG_DIR/realsense.log"
echo "标签3: FAST-LIVO      日志: $LOG_DIR/fastlivo.log"
echo "=========================================="
echo ""
echo "停止所有节点: ./stop_all.sh"
