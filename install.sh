#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

cur_dir=$(pwd)

# check root
[[ $EUID -ne 0 ]] && echo -e "${red}sai lầm：${plain} Tập lệnh này phải được chạy với tư cách người dùng root!\n" && exit 1

# check os
if [[ -f /etc/redhat-release ]]; then
    release="centos"
elif cat /etc/issue | grep -Eqi "debian"; then
    release="debian"
elif cat /etc/issue | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /etc/issue | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
elif cat /proc/version | grep -Eqi "debian"; then
    release="debian"
elif cat /proc/version | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /proc/version | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
else
    echo -e "${red}Không tìm thấy phiên bản hệ thống, vui lòng liên hệ với tác giả tập lệnh！${plain}\n" && exit 1
fi

arch=$(arch)

if [[ $arch == "x86_64" || $arch == "x64" || $arch == "amd64" ]]; then
    arch="amd64"
elif [[ $arch == "aarch64" || $arch == "arm64" ]]; then
    arch="arm64"
elif [[ $arch == "s390x" ]]; then
    arch="s390x"
else
    arch="amd64"
    echo -e "${red}Không phát hiện được kiến ​​trúc, sử dụng kiến ​​trúc mặc định: ${arch}${plain}"
fi

echo "Ngành kiến ​​​​trúc: ${arch}"

if [ $(getconf WORD_BIT) != '32' ] && [ $(getconf LONG_BIT) != '64' ]; then
    echo "Phần mềm này không hỗ trợ hệ thống bit 32(x86)，Vui lòng sử dụng hệ thống 64 bit (x86_64). Nếu phát hiện không chính xác, vui lòng liên hệ với tác giả."
    exit -1
fi

os_version=""

# os version
if [[ -f /etc/os-release ]]; then
    os_version=$(awk -F'[= ."]' '/VERSION_ID/{print $3}' /etc/os-release)
fi
if [[ -z "$os_version" && -f /etc/lsb-release ]]; then
    os_version=$(awk -F'[= ."]+' '/DISTRIB_RELEASE/{print $2}' /etc/lsb-release)
fi

if [[ x"${release}" == x"centos" ]]; then
    if [[ ${os_version} -le 6 ]]; then
        echo -e "${red}Vui lòng sử dụng CentOS 7 trở lên!${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"ubuntu" ]]; then
    if [[ ${os_version} -lt 16 ]]; then
        echo -e "${red}Vui lòng sử dụng Ubuntu 16 trở lên!${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"debian" ]]; then
    if [[ ${os_version} -lt 8 ]]; then
        echo -e "${red}Vui lòng sử dụng phiên bản hệ thống Debian 8 trở lên!${plain}\n" && exit 1
    fi
fi

install_base() {
    if [[ x"${release}" == x"centos" ]]; then
        yum install wget curl tar -y
    else
        apt install wget curl tar -y
    fi
}

#This function will be called when user installed x-ui out of sercurity
config_after_install() {
    echo -e "${yellow}menjmoi: Vì lý do bảo mật, bạn cần thay đổi mạnh mẽ cổng và mật khẩu tài khoản sau khi hoàn tất cài đặt/cập nhật.${plain}"
    read -p "Bạn có chắc chắn muốn tiếp tục không? [y/n]": config_confirm
    if [[ x"${config_confirm}" == x"y" || x"${config_confirm}" == x"Y" ]]; then
        read -p "Vui lòng đặt tên tài khoản của bạn: " config_account
        echo -e "${yellow}Tên tài khoản của bạn sẽ được đặt thành:${config_account}${plain}"
        read -p "Vui lòng đặt mật khẩu tài khoản của bạn: " config_password
        echo -e "${yellow}Mật khẩu tài khoản của bạn sẽ được đặt thành:${config_password}${plain}"
        read -p "Vui lòng đặt cổng truy cập bảng điều khiển: " config_port
        echo -e "${yellow}Cổng truy cập bảng điều khiển của bạn sẽ được đặt thành:${config_port}${plain}"
        echo -e "${yellow}Xác nhận cài đặt, cài đặt${plain}"
        /usr/local/x-ui/x-ui setting -username ${config_account} -password ${config_password}
        echo -e "${yellow}Đã hoàn tất cài đặt mật khẩu tài khoản${plain}"
        /usr/local/x-ui/x-ui setting -port ${config_port}
        echo -e "${yellow}Đã hoàn tất cài đặt cổng bảng điều khiển${plain}"
    else
        echo -e "${red}Đã hủy, tất cả cài đặt là cài đặt mặc định, vui lòng sửa đổi chúng kịp thời${plain}"
    fi
}

install_x-ui() {
    systemctl stop x-ui
    cd /usr/local/

    if [ $# == 0 ]; then
        last_version=$(curl -Ls "https://api.github.com/repos/vaxilu/x-ui/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
        if [[ ! -n "$last_version" ]]; then
            echo -e "${red}Không phát hiện được phiên bản x-ui. Có thể do giới hạn API Github đã vượt quá. Vui lòng thử lại sau hoặc chỉ định phiên bản x-ui theo cách thủ công để cài đặt.${plain}"
            exit 1
        fi
        echo -e "Phiên bản mới nhất của x-ui được phát hiện: ${last_version}, bắt đầu cài đặt"
        wget -N --no-check-certificate -O /usr/local/x-ui-linux-${arch}.tar.gz https://github.com/vaxilu/x-ui/releases/download/${last_version}/x-ui-linux-${arch}.tar.gz
        if [[ $? -ne 0 ]]; then
            echo -e "${red}Không tải xuống được x-ui, vui lòng đảm bảo rằng máy chủ của bạn có thể tải xuống các tệp Github ${plain}"
            exit 1
        fi
    else
        last_version=$1
        url="https://github.com/vaxilu/x-ui/releases/download/${last_version}/x-ui-linux-${arch}.tar.gz"
        echo -e "Bắt đầu cài đặt x-ui v$1"
        wget -N --no-check-certificate -O /usr/local/x-ui-linux-${arch}.tar.gz ${url}
        if [[ $? -ne 0 ]]; then
            echo -e "${red}Tải xuống x-ui v$1 không thành công, vui lòng đảm bảo phiên bản này tồn tại ${plain}"
            exit 1
        fi
    fi

    if [[ -e /usr/local/x-ui/ ]]; then
        rm /usr/local/x-ui/ -rf
    fi

    tar zxvf x-ui-linux-${arch}.tar.gz
    rm x-ui-linux-${arch}.tar.gz -f
    cd x-ui
    chmod +x x-ui bin/xray-linux-${arch}
    cp -f x-ui.service /etc/systemd/system/
    wget --no-check-certificate -O /usr/bin/x-ui https://raw.githubusercontent.com/vaxilu/x-ui/main/x-ui.sh
    chmod +x /usr/local/x-ui/x-ui.sh
    chmod +x /usr/bin/x-ui
    config_after_install
    systemctl daemon-reload
    systemctl enable x-ui
    systemctl start x-ui
    echo -e "${green}x-ui v${last_version}${plain} Quá trình cài đặt hoàn tất và bảng điều khiển được bắt đầu，"
    echo -e ""
    echo -e "Cách sử dụng tập lệnh quản lý x-ui - Việt hóa by menjmoi: "
    echo -e "----------------------------------------------"
    echo -e "x-ui - hiển thị menu quản lý (nhiều chức năng hơn)"
    echo -e "x-ui start - Khởi động bảng x-ui"
    echo -e "x-ui stop - Dừng bảng x-ui"
    echo -e "x-ui restart - Khởi động lại bảng x-ui"
    echo -e "trạng thái x-ui - Xem trạng thái x-ui"
    echo -e "bật x-ui - Đặt x-ui tự động khởi động khi khởi động"
    echo -e "tắt x-ui - Hủy khởi động x-ui khi khởi động"
    echo -e "x-ui log - Xem nhật ký x-ui"
    echo -e "x-ui v2-ui - di chuyển dữ liệu tài khoản v2-ui của máy này sang x-ui"
    echo -e "cập nhật x-ui - cập nhật bảng x-ui"
    echo -e "cài đặt x-ui - cài đặt bảng điều khiển x-ui"
    echo -e "gỡ cài đặt x-ui - Gỡ cài đặt bảng x-ui"
    echo -e "----------------------------------------------"
}

echo -e "${green}menjmoi - bắt đầu cài đặt${plain}"
install_base
install_x-ui $1
