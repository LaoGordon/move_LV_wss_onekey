#!/bin/bash

###############################################################################
# FAST-LIVO 一键启动脚本
# 在一个终端窗口的三个标签页中分别启动所有节点，输出同时保存到日志
###############################################################################

# 获取脚本所在目录
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# 创建日志目录
LOG_DIR="$SCRIPT_DIR/logs"
mkdir -p "$LOG_DIR"

echo "=========================================="
echo "  FAST-LIVO 系统启动"
echo "=========================================="
echo ""
echo "日志目录: $LOG_DIR"
echo ""

# 启动一个终端窗口，包含三个标签页
gnome-terminal --tab --title="Livox Driver" -- bash -c "
    cd '$SCRIPT_DIR/livox_ws' && source install/setup.bash
    ros2 launch livox_ros_driver2 msg_MID360_launch.py 2>&1 | tee '$LOG_DIR/livox_driver.log'
    read
" --tab --title="RealSense Camera" -- bash -c "
    cd '$SCRIPT_DIR' && source /opt/ros/humble/setup.bash
    ros2 launch realsense2_camera rs_launch.py rgb_camera.profile:=640x480x30 align_depth.enable:=false 2>&1 | tee '$LOG_DIR/realsense.log'
    read
" --tab --title="FAST-LIVO" -- bash -c "
    cd '$SCRIPT_DIR' && source /opt/ros/humble/setup.bash && source '$SCRIPT_DIR/livox_ws/install/setup.bash' && source '$SCRIPT_DIR/fastlivo2_ws/install/setup.bash'
    ros2 launch fast_livo mapping_mid360.launch.py 2>&1 | tee '$LOG_DIR/fastlivo.log'
    read
"

echo ""
echo "=========================================="
echo "已在终端窗口的三个标签页中启动所有节点！"
echo "=========================================="
echo "标签1: Livox Driver   日志: $LOG_DIR/livox_driver.log"
echo "标签2: RealSense Camera 日志: $LOG_DIR/realsense.log"
echo "标签3: FAST-LIVO      日志: $LOG_DIR/fastlivo.log"
echo "=========================================="
echo ""
echo "停止所有节点: ./stop_all.sh"
