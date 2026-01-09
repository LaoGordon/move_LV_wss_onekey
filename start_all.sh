#!/bin/bash

###############################################################################
# FAST-LIVO 一键启动脚本
# 支持前台和后台两种模式启动所有节点
###############################################################################

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 获取脚本所在目录
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# 创建日志目录
LOG_DIR="$SCRIPT_DIR/logs"
mkdir -p "$LOG_DIR"

# 显示菜单
show_menu() {
    echo ""
    echo -e "${GREEN}==================================${NC}"
    echo -e "${GREEN}  FAST-LIVO 启动模式选择${NC}"
    echo -e "${GREEN}==================================${NC}"
    echo "1) 后台运行（默认）- 所有节点后台运行，输出重定向到日志"
    echo "2) 前台运行FAST-LIVO - Livox和相机后台运行，FAST-LIVO前台显示输出"
    echo "3) 仅启动Livox驱动 - 前台显示Livox驱动输出（调试用）"
    echo "4) 仅启动相机 - 前台显示相机输出（调试用）"
    echo "5) 交互式选择 - 逐个选择要启动的节点"
    echo "0) 退出"
    echo -e "${GREEN}==================================${NC}"
    echo ""
}

# 获取用户选择
get_user_choice() {
    if [ $# -gt 0 ]; then
        # 命令行参数优先
        case $1 in
            -b|--background)
                return 1
                ;;
            -f|--foreground)
                return 2
                ;;
            -l|--livox)
                return 3
                ;;
            -c|--camera)
                return 4
                ;;
            -i|--interactive)
                return 5
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                echo -e "${RED}未知选项: $1${NC}"
                show_help
                exit 1
                ;;
        esac
    else
        # 交互式菜单
        show_menu
        read -p "请选择启动模式 [1-5, 0=退出]: " choice
        case $choice in
            1) return 1 ;;
            2) return 2 ;;
            3) return 3 ;;
            4) return 4 ;;
            5) return 5 ;;
            0) exit 0 ;;
            *)
                echo -e "${RED}无效选择，使用默认模式（后台运行）${NC}"
                return 1
                ;;
        esac
    fi
}

# 显示帮助信息
show_help() {
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  -b, --background     后台运行，输出重定向到日志文件（默认）"
    echo "  -f, --foreground    Livox和相机后台运行，FAST-LIVO前台显示输出"
    echo "  -l, --livox         仅启动Livox驱动（前台，调试用）"
    echo "  -c, --camera        仅启动相机（前台，调试用）"
    echo "  -i, --interactive   交互式选择启动的节点"
    echo "  -h, --help          显示此帮助信息"
    echo ""
    echo "示例:"
    echo "  $0                  # 默认后台运行"
    echo "  $0 --foreground     # FAST-LIVO前台运行"
    echo "  $0 --livox          # 仅启动Livox驱动（调试）"
    echo "  $0 -i               # 交互式选择"
}

# 解析命令行参数或显示菜单
MODE=$(get_user_choice "$@")

# 根据模式启动
case $MODE in
    1) # 后台运行所有节点
        echo -e "${GREEN}==================================${NC}"
        echo -e "${GREEN}  FAST-LIVO 系统启动${NC}"
        echo -e "${GREEN}==================================${NC}"
        echo -e "运行模式: ${YELLOW}后台运行${NC} (输出重定向到日志文件)"
        echo "日志目录: $LOG_DIR"
        echo ""

        # 启动 Livox 驱动
        echo -e "${BLUE}[INFO]${NC} 启动 Livox 驱动 (后台)..."
        cd "$SCRIPT_DIR/livox_ws" && source install/setup.bash
        nohup ros2 launch livox_ros_driver2 msg_MID360_launch.py > "$LOG_DIR/livox_driver.log" 2>&1 &
        LIVOX_PID=$!
        echo "Livox 驱动 PID: $LIVOX_PID"
        echo "$LIVOX_PID" > "$LOG_DIR/livox_driver.pid"
        sleep 3

        # 启动 RealSense 相机
        echo -e "${BLUE}[INFO]${NC} 启动 RealSense 相机 (后台)..."
        cd "$SCRIPT_DIR" && source /opt/ros/humble/setup.bash
        nohup ros2 launch realsense2_camera rs_launch.py rgb_camera.profile:=640x480x30 align_depth.enable:=false > "$LOG_DIR/realsense.log" 2>&1 &
        REALSENSE_PID=$!
        echo "RealSense 相机 PID: $REALSENSE_PID"
        echo "$REALSENSE_PID" > "$LOG_DIR/realsense.pid"
        sleep 3

        # 启动 FAST-LIVO
        echo -e "${BLUE}[INFO]${NC} 启动 FAST-LIVO (后台)..."
        cd "$SCRIPT_DIR" && source /opt/ros/humble/setup.bash && source "$SCRIPT_DIR/livox_ws/install/setup.bash" && source "$SCRIPT_DIR/fastlivo2_ws/install/setup.bash"
        nohup ros2 launch fast_livo mapping_mid360.launch.py > "$LOG_DIR/fastlivo.log" 2>&1 &
        FASTLIVO_PID=$!
        echo "FAST-LIVO PID: $FASTLIVO_PID"
        echo "$FASTLIVO_PID" > "$LOG_DIR/fastlivo.pid"
        sleep 2

        echo ""
        echo -e "${GREEN}==================================${NC}"
        echo -e "${GREEN}所有节点已在后台启动！${NC}"
        echo -e "${GREEN}==================================${NC}"
        echo "Livox 驱动   PID: $LIVOX_PID   日志: $LOG_DIR/livox_driver.log"
        echo "RealSense 相机 PID: $REALSENSE_PID   日志: $LOG_DIR/realsense.log"
        echo "FAST-LIVO    PID: $FASTLIVO_PID   日志: $LOG_DIR/fastlivo.log"
        echo -e "${GREEN}==================================${NC}"
        echo ""
        echo -e "${BLUE}查看实时日志示例：${NC}"
        echo "  tail -f $LOG_DIR/livox_driver.log"
        echo "  tail -f $LOG_DIR/realsense.log"
        echo "  tail -f $LOG_DIR/fastlivo.log"
        echo ""
        echo -e "${BLUE}停止所有节点: ./stop_all.sh${NC}"
        ;;

    2) # 前台运行FAST-LIVO
        echo -e "${GREEN}==================================${NC}"
        echo -e "${GREEN}  FAST-LIVO 系统启动${NC}"
        echo -e "${GREEN}==================================${NC}"
        echo -e "运行模式: ${GREEN}FAST-LIVO前台运行${NC} (其他节点后台)"
        echo ""

        # 启动 Livox 驱动（后台）
        echo -e "${BLUE}[INFO]${NC} 启动 Livox 驱动 (后台)..."
        cd "$SCRIPT_DIR/livox_ws" && source install/setup.bash
        nohup ros2 launch livox_ros_driver2 msg_MID360_launch.py > "$LOG_DIR/livox_driver.log" 2>&1 &
        LIVOX_PID=$!
        echo "Livox 驱动 PID: $LIVOX_PID (后台)"
        echo "$LIVOX_PID" > "$LOG_DIR/livox_driver.pid"
        sleep 3

        # 启动 RealSense 相机（后台）
        echo -e "${BLUE}[INFO]${NC} 启动 RealSense 相机 (后台)..."
        cd "$SCRIPT_DIR" && source /opt/ros/humble/setup.bash
        nohup ros2 launch realsense2_camera rs_launch.py rgb_camera.profile:=640x480x30 align_depth.enable:=false > "$LOG_DIR/realsense.log" 2>&1 &
        REALSENSE_PID=$!
        echo "RealSense 相机 PID: $REALSENSE_PID (后台)"
        echo "$REALSENSE_PID" > "$LOG_DIR/realsense.pid"
        sleep 3

        # 启动 FAST-LIVO（前台）
        echo ""
        echo -e "${GREEN}[INFO]${NC} 启动 FAST-LIVO (前台，显示输出)..."
        echo "按 Ctrl+C 停止 FAST-LIVO，其他节点继续运行"
        echo ""
        cd "$SCRIPT_DIR" && source /opt/ros/humble/setup.bash && source "$SCRIPT_DIR/livox_ws/install/setup.bash" && source "$SCRIPT_DIR/fastlivo2_ws/install/setup.bash"
        ros2 launch fast_livo mapping_mid360.launch.py
        ;;

    3) # 仅启动Livox驱动（前台）
        echo -e "${GREEN}==================================${NC}"
        echo -e "${GREEN}  仅启动 Livox 驱动${NC}"
        echo -e "${GREEN}==================================${NC}"
        echo -e "运行模式: ${GREEN}前台运行${NC}"
        echo "日志目录: $LOG_DIR"
        echo ""
        cd "$SCRIPT_DIR/livox_ws" && source install/setup.bash
        ros2 launch livox_ros_driver2 msg_MID360_launch.py
        ;;

    4) # 仅启动相机（前台）
        echo -e "${GREEN}==================================${NC}"
        echo -e "${GREEN}  仅启动 RealSense 相机${NC}"
        echo -e "${GREEN}==================================${NC}"
        echo -e "运行模式: ${GREEN}前台运行${NC}"
        echo "日志目录: $LOG_DIR"
        echo ""
        cd "$SCRIPT_DIR" && source /opt/ros/humble/setup.bash
        ros2 launch realsense2_camera rs_launch.py rgb_camera.profile:=640x480x30 align_depth.enable:=false
        ;;

    5) # 交互式选择
        echo ""
        echo "请选择要启动的节点（可多选，用空格分隔）:"
        echo "1) Livox 驱动"
        echo "2) RealSense 相机"
        echo "3) FAST-LIVO"
        echo "4) 全部启动（后台）"
        read -p "选择 [1-4]: " choices
        
        for choice in $choices; do
            case $choice in
                1)
                    echo -e "${BLUE}[INFO]${NC} 启动 Livox 驱动..."
                    cd "$SCRIPT_DIR/livox_ws" && source install/setup.bash
                    ros2 launch livox_ros_driver2 msg_MID360_launch.py
                    ;;
                2)
                    echo -e "${BLUE}[INFO]${NC} 启动 RealSense 相机..."
                    cd "$SCRIPT_DIR" && source /opt/ros/humble/setup.bash
                    ros2 launch realsense2_camera rs_launch.py rgb_camera.profile:=640x480x30 align_depth.enable:=false
                    ;;
                3)
                    echo -e "${BLUE}[INFO]${NC} 启动 FAST-LIVO..."
                    cd "$SCRIPT_DIR" && source /opt/ros/humble/setup.bash && source "$SCRIPT_DIR/livox_ws/install/setup.bash" && source "$SCRIPT_DIR/fastlivo2_ws/install/setup.bash"
                    ros2 launch fast_livo mapping_mid360.launch.py
                    ;;
                4)
                    echo -e "${BLUE}[INFO]${NC} 启动所有节点（后台）..."
                    # 后台启动所有节点
                    cd "$SCRIPT_DIR/livox_ws" && source install/setup.bash
                    nohup ros2 launch livox_ros_driver2 msg_MID360_launch.py > "$LOG_DIR/livox_driver.log" 2>&1 &
                    LIVOX_PID=$!
                    echo "Livox 驱动 PID: $LIVOX_PID"
                    echo "$LIVOX_PID" > "$LOG_DIR/livox_driver.pid"
                    
                    cd "$SCRIPT_DIR" && source /opt/ros/humble/setup.bash
                    nohup ros2 launch realsense2_camera rs_launch.py rgb_camera.profile:=640x480x30 align_depth.enable:=false > "$LOG_DIR/realsense.log" 2>&1 &
                    REALSENSE_PID=$!
                    echo "RealSense 相机 PID: $REALSENSE_PID"
                    echo "$REALSENSE_PID" > "$LOG_DIR/realsense.pid"
                    
                    cd "$SCRIPT_DIR" && source /opt/ros/humble/setup.bash && source "$SCRIPT_DIR/livox_ws/install/setup.bash" && source "$SCRIPT_DIR/fastlivo2_ws/install/setup.bash"
                    nohup ros2 launch fast_livo mapping_mid360.launch.py > "$LOG_DIR/fastlivo.log" 2>&1 &
                    FASTLIVO_PID=$!
                    echo "FAST-LIVO PID: $FASTLIVO_PID"
                    echo "$FASTLIVO_PID" > "$LOG_DIR/fastlivo.pid"
                    echo "所有节点已在后台启动！"
                    ;;
                *)
                    echo -e "${RED}无效选择: $choice${NC}"
                    ;;
            esac
        done
        ;;
esac
