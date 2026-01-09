#!/bin/bash

###############################################################################
# 自动编译LV项目所有工作空间
# 用途：将LV目录移动到新电脑后，一键编译所有ROS2工作空间
###############################################################################

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查命令是否存在
check_command() {
    if ! command -v $1 &> /dev/null; then
        log_error "$1 未找到，请先安装"
        return 1
    fi
    return 0
}

# 检查ROS2环境
check_ros2() {
    log_info "检查ROS2环境..."
    
    if [ -z "$ROS_DISTRO" ]; then
        log_error "ROS2环境未设置，请先source ROS2环境"
        log_info "运行: source /opt/ros/humble/setup.bash"
        return 1
    fi
    
    log_success "ROS2环境已设置: $ROS_DISTRO"
    return 0
}

# 检查并安装ROS2依赖包
check_ros2_dependencies() {
    log_info "检查ROS2依赖包..."
    
    local missing_packages=()
    local ros_distro=${ROS_DISTRO:-humble}
    
    # 检查常用的ROS2依赖包
    local packages=(
        "pcl-ros"
        "pcl-conversions"
        "cv-bridge"
        "sensor-msgs"
        "geometry-msgs"
        "nav-msgs"
        "tf2-ros"
        "tf2-geometry-msgs"
        "xacro"
        "realsense2-camera"
    )
    
    for pkg in "${packages[@]}"; do
        if ! dpkg -l | grep -q "ros-${ros_distro}-${pkg}"; then
            missing_packages+=("ros-${ros_distro}-${pkg}")
        else
            log_success "${pkg} 已安装"
        fi
    done
    
    # 如果有缺失的包，询问是否安装
    if [ ${#missing_packages[@]} -gt 0 ]; then
        log_warning "发现 ${#missing_packages[@]} 个缺失的ROS2包:"
        for pkg in "${missing_packages[@]}"; do
            echo "  - $pkg"
        done
        echo ""
        log_info "正在自动安装缺失的包..."
        
        # 更新包列表
        if ! sudo apt update; then
            log_error "apt update 失败！"
            return 1
        fi
        
        # 安装所有缺失的包
        if sudo apt install -y "${missing_packages[@]}"; then
            log_success "所有依赖包安装成功！"
            return 0
        else
            log_error "依赖包安装失败！"
            log_info "请手动运行以下命令安装:"
            echo "  sudo apt install ${missing_packages[*]}"
            return 1
        fi
    else
        log_success "所有ROS2依赖包已安装"
        return 0
    fi
}

# 检查Sophus依赖
check_sophus() {
    log_info "检查Sophus依赖..."
    
    # 方法1: 检查dpkg包
    if dpkg -l | grep -q "ros-humble-sophus"; then
        log_success "Sophus已安装: ros-humble-sophus"
        return 0
    fi
    
    # 方法2: 检查头文件
    if [ -f "/opt/ros/humble/include/sophus/se3.hpp" ] || [ -f "/usr/include/sophus/se3.hpp" ] || [ -f "/usr/local/include/sophus/se3.hpp" ]; then
        log_success "Sophus头文件已找到"
        return 0
    fi
    
    # 方法3: 尝试pkg-config
    if pkg-config --exists sophus 2>/dev/null; then
        log_success "Sophus已安装 (pkg-config)"
        return 0
    fi
    
    log_error "Sophus未找到！FAST-LIVO2需要Sophus库"
    echo ""
    log_info "正在自动安装ros-humble-sophus..."
    if sudo apt update && sudo apt install -y ros-humble-sophus; then
        log_success "Sophus安装成功!"
        return 0
    else
        log_error "Sophus安装失败！"
        log_info "请手动安装Sophus:"
        echo "  sudo apt install ros-humble-sophus"
        echo ""
        log_info "或者手动编译安装:"
        echo "  git clone https://github.com/strasdat/Sophus.git"
        echo "  cd Sophus"
        echo "  git checkout a621ff"
        echo "  mkdir build && cd build && cmake .."
        echo "  make"
        echo "  sudo make install"
        return 1
    fi
}

# 检查Livox-SDK2是否已安装
check_livox_sdk_installed() {
    # 检查关键文件是否存在
    if [ -f "/usr/local/lib/liblivox_lidar_sdk_shared.so" ] && \
       [ -f "/usr/local/include/livox_lidar_api.h" ] && \
       [ -f "/usr/local/include/livox_lidar_def.h" ] && \
       [ -f "/usr/local/include/livox_lidar_cfg.h" ]; then
        return 0
    fi
    return 1
}

# 编译和安装Livox-SDK2
setup_livox_sdk() {
    log_info "========================================"
    log_info "检查Livox-SDK2安装状态"
    log_info "========================================"
    
    # 检查是否已安装
    if check_livox_sdk_installed; then
        log_success "Livox-SDK2已安装，跳过编译和安装步骤"
        log_info "检测到的文件:"
        echo "  - /usr/local/lib/liblivox_lidar_sdk_shared.so"
        echo "  - /usr/local/lib/liblivox_lidar_sdk_static.a"
        echo "  - /usr/local/include/livox_lidar_api.h"
        echo "  - /usr/local/include/livox_lidar_def.h"
        echo "  - /usr/local/include/livox_lidar_cfg.h"
        return 0
    fi
    
    log_warning "Livox-SDK2未安装，开始编译和安装..."
    
    local livox_sdk_dir="$SCRIPT_DIR/Livox-SDK2"
    
    # 检查Livox-SDK2目录是否存在
    if [ ! -d "$livox_sdk_dir" ]; then
        log_error "Livox-SDK2目录不存在: $livox_sdk_dir"
        return 1
    fi
    
    # 保存当前目录
    local current_dir=$(pwd)
    
    # 进入Livox-SDK2目录
    cd "$livox_sdk_dir"
    
    # 清理旧的构建文件
    log_info "清理旧的构建文件..."
    rm -rf build
    
    # 创建构建目录
    mkdir -p build
    cd build
    
    # 编译
    log_info "开始编译Livox-SDK2..."
    if cmake ..; then
        log_success "CMake配置成功"
    else
        log_error "CMake配置失败！"
        cd "$current_dir"
        return 1
    fi
    
    if make -j$(nproc); then
        log_success "Livox-SDK2编译成功"
    else
        log_error "Livox-SDK2编译失败！"
        cd "$current_dir"
        return 1
    fi
    
    # 安装
    log_info "安装Livox-SDK2（需要sudo权限）..."
    if sudo make install; then
        log_success "Livox-SDK2安装成功!"
        cd "$current_dir"
        return 0
    else
        log_error "Livox-SDK2安装失败！"
        cd "$current_dir"
        return 1
    fi
}

# 检查工作空间是否已经成功编译
check_workspace_built() {
    local workspace_path=$1
    
    # 检查install目录是否存在
    if [ ! -d "$workspace_path/install" ]; then
        return 1
    fi
    
    # 检查install目录下是否有setup.bash
    if [ ! -f "$workspace_path/install/setup.bash" ]; then
        return 1
    fi
    
    # 检查build目录是否存在
    if [ ! -d "$workspace_path/build" ]; then
        return 1
    fi
    
    # 检查build目录下是否有COLCON_IGNORE文件（如果有说明之前的编译被标记为失败）
    if [ -f "$workspace_path/build/COLCON_IGNORE" ]; then
        return 1
    fi
    
    return 0
}

# 清理并编译工作空间
build_workspace() {
    local workspace_name=$1
    local workspace_path=$2
    local force_rebuild=$3  # 可选参数：是否强制重新编译
    
    log_info "========================================"
    log_info "开始编译工作空间: $workspace_name"
    log_info "路径: $workspace_path"
    log_info "========================================"
    
    # 检查工作空间是否存在
    if [ ! -d "$workspace_path" ]; then
        log_error "工作空间不存在: $workspace_path"
        return 1
    fi
    
    # 检查src目录是否存在
    if [ ! -d "$workspace_path/src" ]; then
        log_error "src目录不存在: $workspace_path/src"
        return 1
    fi
    
    # 检查是否已经编译成功，如果不是强制重新编译
    if [ "$force_rebuild" != "true" ] && check_workspace_built "$workspace_path"; then
        log_success "工作空间 $workspace_name 已编译，跳过编译"
        log_info "如需重新编译，请使用 --rebuild 选项"
        return 0
    fi
    
    # 保存当前目录
    local current_dir=$(pwd)
    
    # 进入工作空间目录
    cd "$workspace_path"
    
    # 清理旧的构建文件
    log_info "清理旧的构建文件..."
    rm -rf build install log
    
    # 创建目录和COLCON_IGNORE文件以忽略colcon警告
    mkdir -p build install log
    touch build/COLCON_IGNORE install/COLCON_IGNORE log/COLCON_IGNORE
    
    # 编译
    log_info "开始编译..."
    
    # 如果是fastlivo2_ws，先source livox_ws的install目录
    if [ "$workspace_name" == "fastlivo2_ws" ]; then
        log_info "Source livox_ws工作空间以解决依赖..."
        source "$SCRIPT_DIR/livox_ws/install/setup.bash" 2>/dev/null || true
    fi
    
    # 移除COLCON_IGNORE文件，让colcon可以正常编译
    rm -f build/COLCON_IGNORE
    
    if colcon build --symlink-install --continue-on-error; then
        log_success "工作空间 $workspace_name 编译成功!"
        # 返回原始目录
        cd "$current_dir"
        return 0
    else
        log_error "工作空间 $workspace_name 编译失败!"
        # 标记编译失败
        touch build/COLCON_IGNORE
        # 返回原始目录
        cd "$current_dir"
        return 1
    fi
}

# 主函数
main() {
    local force_rebuild=false
    
    # 检查是否传入 --rebuild 参数
    if [ "$1" == "--rebuild" ]; then
        force_rebuild=true
        log_warning "强制重新编译模式已启用"
    fi
    
    echo -e "${GREEN}"
    echo "========================================"
    echo "  LV工作空间自动编译脚本"
    echo "========================================"
    echo -e "${NC}"
    
    # 记录开始时间
    START_TIME=$(date +%s)
    
    # 检查必要命令
    log_info "检查必要命令..."
    check_command colcon || exit 1
    check_command cmake || exit 1
    
    # 检查ROS2环境
    check_ros2 || exit 1
    
    # 检查ROS2依赖包
    check_ros2_dependencies || exit 1
    
    # 检查Sophus依赖
    check_sophus || exit 1
    
    # 编译和安装Livox-SDK2
    setup_livox_sdk || exit 1
    
    # 统计编译结果
    SUCCESS_COUNT=0
    FAILED_COUNT=0
    SKIPPED_COUNT=0
    TOTAL_WORKSPACES=2
    
    # 编译工作空间（注意顺序：先编译依赖，再编译依赖它的包）
    WORKSPACES=(
        "livox_ws:livox_ws"
        "fastlivo2_ws:fastlivo2_ws"
    )
    
    for ws_info in "${WORKSPACES[@]}"; do
        IFS=':' read -r ws_name ws_path <<< "$ws_info"
        
        # 检查是否已编译
        if [ "$force_rebuild" != "true" ] && check_workspace_built "$ws_path"; then
            log_info "跳过已编译的工作空间: $ws_name"
            ((SKIPPED_COUNT++))
            echo ""
            continue
        fi
        
        if build_workspace "$ws_name" "$ws_path" "$force_rebuild"; then
            ((SUCCESS_COUNT++))
        else
            ((FAILED_COUNT++))
            log_error "工作空间 $ws_name 编译失败，停止后续工作空间编译"
            break
        fi
        echo ""
    done
    
    # 记录结束时间
    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))
    MINUTES=$((DURATION / 60))
    SECONDS=$((DURATION % 60))
    
    # 打印总结
    echo -e "${GREEN}"
    echo "========================================"
    echo "  编译总结"
    echo "========================================"
    echo -e "${NC}"
    echo "总工作空间数: $TOTAL_WORKSPACES"
    echo -e "编译成功: ${GREEN}$SUCCESS_COUNT${NC}"
    echo -e "跳过已编译: ${YELLOW}$SKIPPED_COUNT${NC}"
    echo -e "编译失败: ${RED}$FAILED_COUNT${NC}"
    echo "总耗时: ${MINUTES}分 ${SECONDS}秒"
    
    if [ $FAILED_COUNT -eq 0 ]; then
        echo ""
        log_success "所有工作空间编译完成!"
        echo ""
        log_info "使用方法:"
        echo "  source fastlivo2_ws/install/setup.bash"
        echo "  ros2 launch fast_livo mapping_mid360.launch.py use_rviz:=True"
        echo ""
        return 0
    else
        echo ""
        log_error "部分工作空间编译失败，请检查错误信息"
        log_info "提示：修复错误后重新运行脚本，会自动跳过已成功编译的工作空间"
        return 1
    fi
}

# 执行主函数
main "$@"
