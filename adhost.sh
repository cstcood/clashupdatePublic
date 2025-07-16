#!/usr/bin/env bash
# Usage: ./to_yaml.sh [hosts_file]
# 如果不指定文件，则从标准输入读取。

file="${1:-/dev/stdin}"

# 临时存储各主机名对应的 IP 列表
declare -A hosts_map

# 逐行读取
while IFS= read -r line || [ -n "$line" ]; do
  # 去掉首尾空白
  l="${line#"${line%%[![:space:]]*}"}"
  l="${l%"${l##*[![:space:]]}"}"
  # 跳过空行或以 # 开头的行
  [[ -z "$l" || "${l:0:1}" == "#" ]] && continue
  # 拆分 IP 和主机名（只取第一个空白前后部分）
  ip="${l%%[[:space:]]*}"
  host="${l#*[[:space:]]}"
  # 累加 IP
  if [[ -n "${hosts_map[$host]}" ]]; then
    hosts_map["$host"]+=" $ip"
  else
    hosts_map["$host"]="$ip"
  fi
done < "$file"

# 输出 YAML

# 对主机名排序输出，保证结果稳定
IFS=$'\n' sorted_hosts=($(printf "%s\n" "${!hosts_map[@]}" | sort))
unset IFS

for host in "${sorted_hosts[@]}"; do
  # 如果主机名包含特殊字符，则用单引号包围
  if [[ "$host" =~ [^A-Za-z0-9.\-] ]]; then
    key="'$host'"
  else
    key="$host"
  fi

  # 将 IP 列表拆为数组
  read -r -a ips <<< "${hosts_map[$host]}"

  if (( ${#ips[@]} > 1 )); then
    # 多个 IP → YAML 数组
    vals=""
    for ip in "${ips[@]}"; do
      # IPv6 地址需要加引号
      if [[ "$ip" == *:* ]]; then
        vals+="'$ip', "
      else
        vals+="$ip, "
      fi
    done
    # 去掉末尾逗号和空格
    vals="[${vals%, }]"
    echo "  $key: $vals"
  else
    # 单个 IP → 标量
    ip="${ips[0]}"
    [[ "$ip" == *:* ]] && ip="'$ip'"
    echo "  $key: $ip"
  fi
done
