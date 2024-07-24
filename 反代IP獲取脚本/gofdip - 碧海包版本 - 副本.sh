#!/bin/bash
################################################################################################################
# 碧海版，可以得到一些非公共域（31898,45102）的反代，相对时效长一些
##################################################功能说明######################################################
# 本脚本为openwrt软路由系统写的，理论上也支持linux类型系统，自行研究。
# 本脚本为全自动下载碧海的反代包，自动筛选有效反代并更新到域名，人人都能拥有自己的反代域名啦。
# 本脚本并不会对反代进行测速，打造良好的反代环境。
# 脚本全明文带中文解说，请仔细查看解说根据自身环境需求修改后执行。
# 根据不同环境和设置，脚本运行时间约半小时（或以上），测试好后放软路由自动运行，并不会影响你的日常网络使用。
# 可在openwrt计划任务中添加定时，比如 0 4 * * * cd /root/CF && bash gofdip.sh 就是每天凌晨4点自动运行。
################################################################################################################
# 重要！！！反代（proxyip）并不是节点，只能填入你的worker或pages作为兜底使用，如果能顺道当节点只是你运气好。
# 重要！！！请在代理（翻墙）环境下运行此脚本，否则此脚本无效。
# 重要！！！请使用自己的cf worker或pages的代理环境并使proxyip指向自己打算更新的反代域名，否则此脚本无效。
# 重要！！！每个人的网络环境不同，不保证脚本有效性，不能用就删了吧>_<。
################################################################################################################
#############################设置API代理网址 有时候国内API无法链接无法下载时使用################################
# 代理网址建议用自己的，随时可能失效
DL="https://dl.houyitfg.icu/proxy/"
##################################################账号设置######################################################
# --cloudflare账号邮箱--
x_email=
#
# --Global API Key--
# --到你托管的域名--右下角“获取您的API令牌”--Global API Key查看
api_key=
#
# --挂载的完整域名，支持同账号下的多域名，需保证第一个域名是你目前连的workers的反代域名--
# --要是不懂就老老实实填一个域名就好--
#	示例：("www.dfsgsdg.com" "www.wrewstdzs.cn")
hostnames=
#################################################反代设置#######################################################
# --验证速度，单位秒，网络不好可以适当增加数值1-5左右比较合理--
speed="1"
#
# --识别后的结果文件夹名称--
FILEPATH="FDIP"
#
# --是否只更新干净IP，true，false，先确认自己的环境是否有对应国家的干净IP--
# --白嫖的反代包干净的可用IP近乎没有，建议false不要改--
cleanip="false"
#
# --选择更新到DNS记录的国家，需确认自己环境能跑出的国家，不要用HK，无法反代--
# --可以先跑一次之后到文件夹下查看具体有哪些国家，个人建议US，相对稳定--
# --就算文件夹下有对应国家也不一定就是有效反代，选择IP较多的国家比较好--
# --如果你对国家没有要求，可以直接填入"FDIP"或"FDIPC"，C是纯净IP，不一定有有效的--
country="US"
#
# --选择更新到DNS记录的IP数量--
# --虽然提供了这个功能，但并不建议挂载多IP，会导致各种网络体验差--
MAX_IPS=1
###################################检查账号及现有反代状态########################################
# 获取区域ID
get_zone_id() {
    local hostname=$1
    curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=$(echo ${hostname} | cut -d "." -f 2-)" -H "X-Auth-Email: $x_email" -H "X-Auth-Key: $api_key" -H "Content-Type: application/json" | jq -r '.result[0].id'
}

# 获取并检查zone_id
for hostname in "${hostnames[@]}"; do
    ZONE_ID=$(get_zone_id "$hostname")

    if [ -z "$ZONE_ID" ]; then
        echo "账号登陆失败，域名: $hostname，检查账号信息"
        exit 1;
    else
        echo "账号登陆成功，域名: $hostname"
    fi
done

# 检查反代及网络环境
if curl -o /dev/null --connect-timeout 5 --max-time 5 -s -w '%{http_code}' "https://chatgpt.com" | grep -qE "200|403"; then
    echo "反代域名正常，不需要更新，脚本停止"
    exit 1;
else
if curl -o /dev/null --connect-timeout 5 --max-time 5 -s -w '%{http_code}' "https://www.youtube.com" | grep -qE "200"; then
    echo "反代域名失效，开始脚本"
else
    echo "重要！！！请在代理（翻墙）环境下运行此脚本，否则此脚本无效。"
    echo "重要！！！请使用自己的cf worker或pages的代理环境并使proxyip指向自己打算更新的反代域名，否则此脚本无效。"
    echo "脚本停止"
    exit 1;
fi
fi
#####################可能需要以下几个依赖，如果无法自动安装就手动自行安装########################
DEPENDENCIES=("curl" "awk" "bash" "jq" "wget" "unzip" "tar" "sed" "grep")

# 检测发行版及其包管理器
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$NAME
    case $OS in
        "Ubuntu"|"Debian"|"Armbian")
            PKG_MANAGER="apt-get"
            UPDATE_CMD="apt-get update"
            INSTALL_CMD="apt-get install -y"
            CHECK_CMD="dpkg -s"
            ;;
        "CentOS"|"Red Hat Enterprise Linux")
            PKG_MANAGER="yum"
            UPDATE_CMD="yum update -y"
            INSTALL_CMD="yum install -y"
            CHECK_CMD="rpm -q"
            ;;
        "Fedora")
            PKG_MANAGER="dnf"
            UPDATE_CMD="dnf update -y"
            INSTALL_CMD="dnf install -y"
            CHECK_CMD="rpm -q"
            ;;
        "Arch Linux")
            PKG_MANAGER="pacman"
            UPDATE_CMD="pacman -Syu"
            INSTALL_CMD="pacman -S --noconfirm"
            CHECK_CMD="pacman -Qi"
            ;;
        "OpenWrt")
            PKG_MANAGER="opkg"
            UPDATE_CMD="opkg update"
            INSTALL_CMD="opkg install"
            CHECK_CMD="opkg list-installed"
            ;;
        *)
            echo "Unsupported Linux distribution: $OS"
            exit 1
            ;;
    esac
else
    echo "Cannot detect Linux distribution."
    exit 1
fi

# 更新包管理器数据库
echo "Updating package database..."
sudo $UPDATE_CMD

# 检测CPU架构
CPU_ARCH=$(uname -m)
echo "CPU Architecture: $CPU_ARCH"

# 根据CPU架构执行特定操作
case $CPU_ARCH in
    "x86_64"|"amd64")
        echo "Running on an AMD64/x86_64 architecture"
        # 针对AMD64/x86_64架构的操作
        ;;
    "armv7l"|"armhf")
        echo "Running on an ARMv7 architecture"
        # 针对ARMv7架构的操作
        ;;
    "aarch64"|"arm64")
        echo "Running on an ARM64 architecture"
        # 针对ARM64架构的操作
        ;;
    *)
        echo "Unsupported CPU architecture: $CPU_ARCH"
        exit 1
        ;;
esac

# 函数：检测依赖项是否已安装
function is_installed {
    case $PKG_MANAGER in
        "apt-get")
            dpkg -s $1 &> /dev/null
            ;;
        "yum"|"dnf")
            rpm -q $1 &> /dev/null
            ;;
        "pacman")
            pacman -Qi $1 &> /dev/null
            ;;
        "opkg")
            opkg list-installed | grep $1 &> /dev/null
            ;;
        *)
            echo "Unsupported package manager: $PKG_MANAGER"
            exit 1
            ;;
    esac
    return $?
}

# 安装依赖项
for DEP in "${DEPENDENCIES[@]}"; do
    echo "Checking if $DEP is installed..."
    if is_installed $DEP; then
        echo "$DEP is already installed."
    else
        echo "Installing $DEP..."
        sudo $INSTALL_CMD $DEP
    fi
done

echo "All dependencies installed successfully."
#################################################################################################
echo "===============================开始下载碧海的反代IP包=================================="
rm -rf "$FILEPATH"
sleep 1 > /dev/null
mkdir "$FILEPATH"
mkdir "$FILEPATH/C"
temp_file="$FILEPATH/FDIPtemp.txt"
curl -s https://cloudcfip.bihai.cf -o $temp_file
sed -i 's/	.*//;' $temp_file
sleep 1 > /dev/null
sort $temp_file | uniq > ip_tmp.txt && mv ip_tmp.txt $temp_file

#######################################验证反代IP及纯净度###########################################
FDIP="$FILEPATH/FDIP.txt"
FDIPC="$FILEPATH/FDIPC.txt"
> $FDIP
> $FDIPC

echo "===========================验证反代IP及纯净度，保留纯净IP=============================="
while IFS= read -r ip; do
urlinfo=$(curl -s --connect-timeout ${speed} --max-time ${speed} "http://$ip/cdn-cgi/trace")
sleep 1 > /dev/null
# 第一步特征，是否正常进入检查页面
if echo "${urlinfo}" | grep -q "h=$ip"; then
    # 第二步特征，剔除国内的，这时候基本已经是反代了
    if ! echo "${urlinfo}" | grep -q "loc=CN"; then
        # 第三步特征，验证反代+反代
        #if ! echo "${urlinfo}" | grep -q "ip=$ip"; then #这是严格验证反代+反代的，结果极少甚至没有结果，不想这么严格可以注释掉[包括下面的一句fi，但是最终准确度不一定对
            DQ=$(echo "${urlinfo}" | awk -F'loc=' '/loc=/ {print $2}') #这是大概识别地区的
            echo "$ip" >> "${FDIP}"
            echo "$ip" >> "$FILEPATH/${DQ}.txt"
            echo "得到一个反代IP[$ip]，落地地区是[${DQ}]"
                if curl -s --connect-timeout 5 --max-time 5 "https://scamalytics.com/ip/$ip" | grep -q '"risk":"low"'; then
                    echo "$ip" >> "${FDIPC}"
                    echo "$ip" >> "$FILEPATH/C/${DQ}.txt"
                    echo "此反代IP纯净[$ip]，落地地区是[${DQ}]"
                fi
        #fi
    fi
else
echo "[$ip]不通或不是反代IP"
fi
done < "$temp_file"

rm -rf $extracted_folder
rm -rf $save_path
echo "IP验证完毕，结果已储存在${FILEPATH}文件夹中，纯净IP文件夹为C，未识别前的文件为FDIPtemp.txt"
#######################################################################################################
echo "================================提取反代IP等待更新DNS===================================="
# 读取反代IP文件
if [ "$cleanip" = "true" ]; then
    test_input_file="$FILEPATH/C/${country}.txt"
    else
    test_input_file="$FILEPATH/${country}.txt"
fi
test_temp_file="fdiptemp.txt"
output_file="FDIP-${country}.txt"

# 检查结果，如果结果为空则跳过更新
if [ ! -f "$test_input_file" ] || ! grep -q '[^[:space:]]' "$test_input_file"; then
    echo "没有提取到对应国家的反代IP，跳过测试更新，查看目录中自己的环境能跑出哪些国家"
    exit 1
fi

# 清空输出文件
> "$test_temp_file"
> "$output_file"

# 读取输入文件中的IP地址并ping，记录结果
while IFS= read -r ip; do
    # 使用ping命令测试IP，并尝试解析输出以获取延迟
    ping_output=$(timeout ${speed}s ping -c 1 -W ${speed} "$ip" 2>&1)
    delay=$(echo "$ping_output" | grep -oP 'time=\d+(\.\d+)?' | head -1 || echo "time=0")
    delay=${delay#time=}
    delay=${delay%}
    # 检查是否获取到延迟信息，并且ping是否成功（通过检查ping的退出状态码）
    if [[ $? -eq 0 && "$delay" != "0" ]]; then
        # 如果ping成功且获取到延迟，将IP地址和延迟写入输出文件
        echo "$ip,$delay" >> "$test_temp_file"
    fi
done < "$test_input_file"
# 读取文件内容，并按照延迟进行排序
awk -F, '{print $NF, $0}' "$test_temp_file" | sort -n -k1,1 | cut -d' ' -f2- | sed 's/,.*//' > "$output_file"
rm -rf $test_temp_file
####################################测试删除并更新DNS记录############################################
# 查询A和AAAA记录的函数
query_records() {
    local zone_id=$1
    local record_type=$2
    local hostname=$3
    curl -s \
        -H "X-Auth-Email: $x_email" \
        -H "X-Auth-Key: $api_key" \
        -H "Content-Type: application/json" \
        "https://api.cloudflare.com/client/v4/zones/$zone_id/dns_records?type=$record_type&name=$hostname&per_page=100&order=type&direction=desc&match=all" |
        jq -r '.result[] | select(.proxied == false) | "\(.id) \(.name) \(.content)"'
}

# 删除记录的函数
delete_record() {
    local zone_id=$1
    local record_id=$2
    local record_name=$3
    local record_content=$4
    response=$(curl -s -o /dev/null -w "%{http_code}" -X DELETE \
        -H "X-Auth-Email: $x_email" \
        -H "X-Auth-Key: $api_key" \
        -H "Content-Type: application/json" \
        "https://api.cloudflare.com/client/v4/zones/$zone_id/dns_records/$record_id")
    if [ "$response" -eq 200 ]; then
        echo "$record_name的DNS记录[$record_content]已成功删除"
    else
        echo "$record_name的DNS记录[$record_content]删除失败"
    fi
}

# 添加记录的函数
add_record() {
    local zone_id=$1
    local ip=$2
    local record_type=$3
    response=$(curl -s -o /dev/null -w "%{http_code}" -X POST \
        -H "X-Auth-Email: $x_email" \
        -H "X-Auth-Key: $api_key" \
        -H "Content-Type: application/json" \
        --data "{\"type\":\"$record_type\",\"name\":\"$hostname\",\"content\":\"$ip\",\"ttl\":60,\"proxied\":false}" \
        "https://api.cloudflare.com/client/v4/zones/$zone_id/dns_records")
    if [ "$response" -eq 200 ]; then
        echo "$hostname的DNS记录[$ip]已成功添加"
    else
        echo "$hostname的DNS记录[$ip]添加失败"
    fi
}

# 处理 DNS 记录的函数
process_dns_records() {
    local hostname=$1
    local zone_id=$2
    local max_ips=$3
    
    echo "正在添加新的DNS记录并测试连通性"
    successful_ips=()
    success_count=0
    while IFS= read -r ip; do
        if [ $success_count -ge $MAX_IPS ]; then
            break
        fi

        if [[ $ip =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            record_type="A"
        elif [[ $ip =~ ^[0-9a-fA-F:]+$ ]]; then
            record_type="AAAA"
        else
            echo "无效的IP地址：$ip"
            continue
        fi

        if add_record "$zone_id" "$ip" "$record_type"; then
            echo "等待65秒后测试连通性"
            sleep 65
            if curl -o /dev/null --connect-timeout 5 -s -w '%{http_code}' "https://chatgpt.com" | grep -qE "200|403"; then
                if (( MAX_IPS == 1 )); then
                    echo "$ip 的GPT连通性测试正常"
                else
                    echo "$ip 的GPT连通性测试正常，继续测试下一个IP"
                fi
                successful_ips+=("$ip")
                success_count=$((success_count + 1))
                # 删除临时记录
                query_records "$zone_id" "$record_type" "$hostname" | while read -r record_id record_name record_content; do
                    if [[ "$record_content" == "$ip" ]]; then
                        delete_record "$zone_id" "$record_id" "$record_name" "$record_content"
                    fi
                done
            else
                echo "$ip 的GPT连通性测试失败，删除该记录并尝试下一个IP。"
                query_records "$zone_id" "$record_type" "$hostname" | while read -r record_id record_name record_content; do
                    if [[ "$record_content" == "$ip" ]]; then
                        delete_record "$zone_id" "$record_id" "$record_name" "$record_content"
                    fi
                done
            fi
        fi
    done < "$output_file"
}

# 删除域名DNS记录
for hostname in "${hostnames[@]}"; do
    ZONE_ID=$(get_zone_id "$hostname")
    for record_type in A AAAA; do
        echo "正在删除 $hostname 的 $record_type 记录..."
        query_records "$ZONE_ID" "$record_type" "$hostname" | while read -r record_id record_name record_content; do
            delete_record "$ZONE_ID" "$record_id" "$record_name" "$record_content"
        done
    done
done

# 处理第一个域名
first_hostname="${hostnames[0]}"
first_zone_id=$(get_zone_id "$first_hostname")

if [ -n "$first_zone_id" ]; then
    process_dns_records "$first_hostname" "$first_zone_id" "$MAX_IPS"
else
    echo "第一个域名 ($first_hostname) 的区域ID获取失败。"
fi

# 同步更新到所有域名
for hostname in "${hostnames[@]}"; do
    ZONE_ID=$(get_zone_id "$hostname")

    if ! [ ${#successful_ips[@]} -eq 0 ]; then
        echo "有 ${#successful_ips[@]} 个有效IP，开始更新最终DNS记录"
        for ip in "${successful_ips[@]}"; do
            if [[ $ip =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                record_type="A"
            elif [[ $ip =~ ^[0-9a-fA-F:]+$ ]]; then
                record_type="AAAA"
            fi
            add_record "$ZONE_ID" "$ip" "$record_type"
        done
        echo "反代域名$hostname更新完成，已成功添加 ${#successful_ips[@]} 个IP地址。"
    else
        echo "反代域名$hostname更新失败，没有合适的有效IP，请手动检查IP吧T_T"
    fi
done