#!/bin/bash

###############################################################################
# FAST-LIVO 一键启动脚本
# 支持多终端窗口同时显示所有节点的输出
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

# 检测终端类型
DETECT_TERMINAL() {
    if [ -n "$DISPLAY" ]; then
        if command -v gnome-terminal &> /dev/null; then
            echo "gnome-terminal"
        elif command -v xterm &> /dev/null; then
            echo "xterm"
        elif command -v konsole &> /dev/null; then
            echo "konsole"
        else
            echo ""
        fi
    else
        echo ""
    fi
}

TERMINAL_CMD=$(DETECT_TERMINAL)

# 显示菜单
show_menu() {
    echo ""
    echo -e "${GREEN}==================================${NC}"
    echo -e "${GREEN}  FAST-LIVO 启动模式选择${NC}"
    echo -e "${GREEN}==================================${NC}"
    if [ -n "$TERMINAL_CMD" ]; then
        echo "1) 多终端运行（推荐）- 打开3个终端窗口分别显示输出"
    else
        echo "1) 后台运行 - 所有节点后台运行，输出重定向到日志"
    fi
    echo "2) 交互式选择 - 逐个选择要启动的节点"
    echo "0) 退出"
    echo -e "${GREEN}==================================${NC}"
    echo ""
}

# 获取用户选择
get_user_choice() {
    if [ $# -gt 0 ]; then
        # 命令行参数优先
        case $1 in
            -m|--multi-terminal)
                if [ -n "$TERMINAL_CMD" ]; then
                    return 1
                else
                    echo -e "${RED}错误：未检测到图形界面终端${NC}"
                    echo -e "${YELLOW}使用后台模式${NC}"
                    return 2
                fi
                ;;
            -b|--background)
                return 2
                ;;
            -i|--interactive)
                return 3
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
        read -p "请选择启动模式 [1-2, 0=退出]: " choice
        case $choice in
            1)
                if [ -n "$TERMINAL_CMD" ]; then
                    return 1
                else
                    echo -e "${RED}错误：未检测到图形界面终端${NC}"
                    echo -e "${YELLOW}使用后台模式${NC}"
                    return 2
                fi
                ;;
            2) return 3 ;;
            0) exit 0 ;;
            *)
                echo -e "${RED}无效选择，使用默认模式${NC}"
                if [ -n "$TERMINAL_CMD" ]; then
                    return 1
                else
                    return 2
                fi
                ;;
        esac
    fi
}

# 显示帮助信息
show_help() {
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  -m, --multi-terminal  多终端运行（需要图形界面，推荐）"
    echo "  -b, --background     后台运行，输出重定向到日志文件"
    echo "  -i, --interactive   交互式选择启动的节点"
    echo "  -h, --help          显示此帮助信息"
    echo ""
    echo "示例:"
    echo "  $0                  # 默认多终端运行"
    echo "  $0 --multi-terminal # 多终端运行"
    echo "  $0 --background     # 后台运行"
    echo "  $0 -i               # 交互式选择"
}

# 解析命令行参数或显示菜单
MODE=$(get_user_choice "$@")

# 根据模式启动
case $MODE in
    1) # 多终端运行
        echo -e "${GREEN}==================================${NC}"
        echo -e "${GREEN}  FAST-LIVO 系统启动${NC}"
        echo -e "${GREEN}==================================${NC}"
        echo -e "运行模式: ${GREEN}多终端运行${NC} (打开3个终端窗口)"
        echo -e "使用的终端: ${YELLOW}$TERMINAL_CMD${NC}"
        echo "日志目录: $LOG_DIR"
        echo ""

        # 启动 Livox 驱动（新终端）
        echo -e "${BLUE}[INFO]${NC} 在新终端启动 Livox 驱动..."
        $TERMINAL_CMD --title="Livox Driver" -- bash -c "
            source '$SCRIPT_DIR/livox_ws/install/setup.bash'
            echo 'Livox 驱动启动中...'
            ros2 launch livox_ros_driver2 msg_MID360_launch.py 2>&1 | tee '$LOG_DIR/livox_driver.log'
            echo ''
            echo 'Livox 驱动已停止，按任意键关闭窗口...'
            read
        " &
        LIVOX_PID=$!
        sleep 1

        # 启动 RealSense 相机（新终端）
        echo -e "${BLUE}[INFO]${NC} 在新终端启动 RealSense 相机..."
        $TERMINAL_CMD --title="RealSense Camera" -- bash -c "
            source /opt/ros/humble/setup.bash
            echo 'RealSense 相机启动中...'
            ros2 launch realsense2_camera rs_launch.py rgb_camera.profile:=640x480x30 align_depth.enable:=false 2>&1 | tee '$LOG_DIR/realsense.log'
            echo ''
            echo 'RealSense 相机已停止，按任意键关闭窗口...'
            read
        " &
        REALSENSE_PID=$!
        sleep 1

        # 启动 FAST-LIVO（新终端）
        echo -e "${BLUE}[INFO]${NC} 在新终端启动 FAST-LIVO..."
        $TERMINAL_CMD --title="FAST-LIVO" -- bash -c "
            source /opt/ros/humble/setup.bash
            source '$SCRIPT_DIR/livox_ws/install/setup.bash'
            source '$SCRIPT_DIR/fastlivo2_ws/install/setup.bash'
            echo 'FAST-LIVO 启动中...'
            ros2 launch fast_livo mapping_mid360.launch.py 2>&1 | tee '$LOG_DIR/fastlivo.log'
            echo ''
            echo 'FAST-LIVO 已停止，按任意键关闭窗口...'
            read
        " &
        FASTLIVO_PID=$!
        sleep 2

        echo ""
        echo -e "${GREEN}==================================${NC}"
        echo -e "${GREEN}已在3个终端窗口启动所有节点！${NC}"
        echo -e "${GREEN}==================================${NC}"
        echo "Livox 驱动   - 终端窗口   日志: $LOG_DIR/livox_driver.log"
        echo "RealSense 相机 - 终端窗口   日志: $LOG_DIR/realsense.log"
        echo "FAST-LIVO    - 终端窗口   日志: $LOG_DIR/fastlivo.log"
        echo -e "${GREEN}==================================${NC}"
        echo ""
        echo -e "${BLUE}提示：${NC}"
        echo "  - 每个终端窗口显示对应节点的实时输出"
        echo "  - 输出同时保存到日志文件"
        echo -e "${BLUE}停止所有节点: ./stop_all.sh${NC}"
        ;;

    2) # 后台运行
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

    3) # 交互式选择
        echo ""
        echo "请选择要启动的节点:"
        echo "1) Livox 驱动"
        echo "2) RealSense 相机"
        echo "3) FAST-LIVO"
        echo "4) 全部启动"
        read -p "选择 [1-4]: " choice
        
        case $choice in
            1)
                echo -e "${BLUE}[INFO]${NC} 启动 Livox 驱动..."
                cd "$SCRIPT_DIR/livox_ws" && source install/setup.bash
                ros2 launch livox_ros_driver2 msg_MID360_launch.py 2>&1 | tee "$LOG_DIR/livox_driver.log"
                ;;
            2)
                echo -e "${BLUE}[INFO]${NC} 启动 RealSense 相机..."
                cd "$SCRIPT_DIR" && source /opt/ros/humble/setup.bash
                ros2 launch realsense2_camera rs_launch.py rgb_camera.profile:=640x480x30 align_depth.enable:=false 2>&1 | tee "$LOG_DIR/realsense.log"
                ;;
            3)
                echo -e "${BLUE}[INFO]${NC} 启动 FAST-LIVO..."
                cd "$SCRIPT_DIR" && source /opt/ros/humble/setup.bash && source "$SCRIPT_DIR/livox_ws/install/setup.bash" && source "$SCRIPT_DIR/fastlivo2_ws/install/setup.bash"
                ros2 launch fast_livo mapping_mid360.launch.py 2>&1 | tee "$LOG_DIR/fastlivo.log"
                ;;
            4)
                if [ -n "$TERMINAL_CMD" ]; then
                    echo -e "${BLUE}[INFO]${NC} 在3个终端启动所有节点..."
                    $TERMINAL_CMD --title="Livox Driver" -- bash -c "
                        source '$SCRIPT_DIR/livox_ws/install/setup.bash'
                        ros2 launch livox_ros_driver2 msg_MID360_launch.py 2>&1 | tee '$LOG_DIR/livox_driver.log'
                        read
                    " &
                    $TERMINAL_CMD --title="RealSense Camera" -- bash -c "
                        source /opt/ros/humble/setup.bash
                        ros2 launch realsense2_camera rs_launch.py rgb_camera.profile:=640x480x30 align_depth.enable:=false 2>&1 | tee '$LOG_DIR/realsense.log'
                        read
                    " &
                    $TERMINAL_CMD --title="FAST-LIVO" -- bash -c "
                        source /opt/ros/humble/setup.bash
                        source '$SCRIPT_DIR/livox_ws/install/setup.bash'
                        source '$SCRIPT_DIR/fastlivo2_ws/install/setup.bash'
                        ros2 launch fast_livo mapping_mid360.launch.py 2>&1 | tee '$LOG_DIR/fastlivo.log'
                        read
                    " &
                else
                    echo -e "${BLUE}[INFO]${NC} 后台启动所有节点..."
                    cd "$SCRIPT_DIR/livox_ws" && source install/setup.bash
                    nohup ros2 launch livox_ros_driver2 msg_MID360_launch.py > "$LOG_DIR/livox_driver.log" 2>&1 &
                    LIVOX_PID=$!
                    echo "$LIVOX_PID" > "$LOG_DIR/livox_driver.pid"
                    
                    cd "$SCRIPT_DIR" && source /opt/ros/humble/setup.bash
                    nohup ros2 launch realsense2_camera rs_launch.py rgb_camera.profile:=640x480x30 align_depth.enable:=false > "$LOG_DIR/realsense.log" 2>&1 &
                    REALSENSE_PID=$!
                    echo "$REALSENSE_PID" > "$LOG_DIR/realsense.pid"
                    
                    cd "$SCRIPT_DIR" && source /opt/ros/humble/setup.bash && source "$SCRIPT_DIR/livox_ws/install/setup.bash" && source "$SCRIPT_DIR/fastlivo2_ws/install/setup.bash"
                    nohup ros2 launch fast_livo mapping_mid360.launch.py > "$LOG_DIR/fastlivo.log" 2>&1 &
                    FASTLIVO_PID=$!
                    echo "$FASTLIVO_PID" > "$LOG_DIR/fastlivo.pid"
                    echo "所有节点已在后台启动！"
                fi
                ;;
            *)
                echo -e "${RED}无效选择: $choice${NC}"
                ;;
        esac
        ;;
esac
