#!/bin/bash

# 脚本保存路径
SCRIPT_PATH="$HOME/Alignedlayer.sh"

# 节点安装功能
function install_node() {
    
    # 更新和安装依赖
    sudo apt update && sudo apt upgrade -y
    sudo apt install curl git jq lz4 build-essential -y
    
    # 安装 Go
    rm -rf $HOME/go
    sudo rm -rf /usr/local/go
    curl -L https://go.dev/dl/go1.22.0.linux-amd64.tar.gz | sudo tar -xzf - -C /usr/local
    echo 'export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin' >> $HOME/.bash_profile
    source $HOME/.bash_profile
    go version
    
    # 下载并安装 Aligned Layer 二进制文件
    cd $HOME
    wget https://github.com/yetanotherco/aligned_layer_tendermint/releases/download/v0.1.0/alignedlayerd
    chmod +x alignedlayerd
    sudo mv alignedlayerd /usr/local/bin/
    
    # 创建节点名称
    read -p "节点名称: " MONIKER
    # 配置节点和创世文件
    alignedlayerd init $MONIKER --chain-id alignedlayer
    
    # 安装创世文件
   curl -Ls https://raw.githubusercontent.com/molla202/AlignedLayer/main/genesis.json > $HOME/.alignedlayer/config/genesis.json
   curl -Ls https://raw.githubusercontent.com/molla202/AlignedLayer/main/addrbook.json > $HOME/.alignedlayer/config/addrbook.json
    
    # 设置配置文件
    SEEDS="d1d43cc7c7aef715957289fd96a114ecaa7ba756@testnet-seeds.nodex.one:24210"
    PERSISTENT_PEERS="125b4260951111e1d7111c071011aec6d24f2087@148.251.82.6:26656,74af08a0cf53d78e3a071c944b355cae95c1c1ef@37.60.243.112:26656,797d6ad9a64abd63b785ce81c75ee7397a590786@213.199.62.101:26656,33a338aef4f9e887571fe7e2baf9dd5baa43e9a2@47.236.180.181:26656,0468a823477832e2dd17c94834ac639ac1929860@213.199.39.156:26656"
    MINIMUM_GAS_PRICES="0.0001stake"
    
    sed -i -e "s|^seeds *=.*|seeds = \"$SEEDS\"|" $HOME/.alignedlayer/config/config.toml
    sed -i -e "s|^persistent_peers *=.*|persistent_peers = \"$PERSISTENT_PEERS\"|" $HOME/.alignedlayer/config/config.toml
    sed -i -e "s|^minimum-gas-prices *=.*|minimum-gas-prices = \"$MINIMUM_GAS_PRICES\"|" $HOME/.alignedlayer/config/app.toml
    
    # 设置启动服务
    sudo tee /etc/systemd/system/alignedlayerd.service > /dev/null <<EOF
[Unit]
Description="Support by breaddog"
After=network-online.target
[Service]
User=$USER
ExecStart=$(which alignedlayerd) start
Restart=always
RestartSec=3
LimitNOFILE=65535
[Install]
WantedBy=multi-user.target
EOF
    
    # 下载快照
    wget $(curl -s https://services.staketab.org/backend/aligned-testnet/ | jq -r .snap_link)
    tar -xf $(curl -s https://services.staketab.org/backend/aligned-testnet/ | jq -r .snap_filename) -C $HOME/.alignedlayer/data/
    
    sudo systemctl daemon-reload
    sudo systemctl enable alignedlayerd
    sudo systemctl start alignedlayerd
    
    echo "====================== 部署完成 ==========================="
        
}

# 创建钱包
function add_wallet() {
    read -r -p "请输入钱包名称: " wallet_name
    alignedlayerd keys add $wallet_name
    echo "钱包已创建，请备份钱包信息。"
}

# 创建验证者
function add_validator() {
    echo "钱包余额需大于1050000stake，否则创建失败..."
    read -r -p "请输入你的钱包名称: " wallet_name
    cd $HOME 
    wget -O setup_validator.sh https://raw.githubusercontent.com/yetanotherco/aligned_layer_tendermint/main/setup_validator.sh 
    chmod +x setup_validator.sh && bash setup_validator.sh $wallet_name 1050000stake
}

# 导入钱包
function import_wallet() {
    read -r -p "请输入钱包名称: " wallet_name
    alignedlayerd keys add $wallet_name --recover
}

# 查询余额
function check_balances() {
    read -p "请输入钱包地址: " wallet_address
    alignedlayerd query bank balances "$wallet_address" 
}

# 查看节点同步状态
function check_sync_status() {
    alignedlayerd status | jq .sync_info
}

# 查看Alignedlayer 服务状态
function check_service_status() {
    systemctl status alignedlayerd
}

# 节点日志查询
function view_logs() {
    sudo journalctl -f -u alignedlayerd.service 
}

# 删除节点
function uninstall_node() {
    sudo systemctl stop alignedlayerd 
    sudo systemctl disable alignedlayerd 
    sudo rm /etc/systemd/system/alignedlayerd.service 
    sudo systemctl daemon-reload 
    rm -rf $HOME/.alignedlayerd 
    rm -rf $HOME/alignedlayer 
    sudo rm -rf $(which alignedlayerd) 
    rm -rf aligned_layer_tendermint 
    rm -rf .alignedlayer
}

# 质押代币
function delegate_stake() {
    read -p "请输入钱包名称: " wallet_name
    read -p "请输入质押代币数量: " math
    validator=$(alignedlayerd keys show $wallet_name --bech val -a)
    # read -p "请输入质押给谁(默认为自己:$validator): " validator_addr
    validator_addr=$validator
    alignedlayerd tx staking delegate $validator_addr ${math}stake \
    --from $wallet_name --chain-id alignedlayer \
    --fees 50stake
}

# 主菜单
function main_menu() {
    while true; do
        clear
        echo "===================AlignedLayer一键部署脚本==================="
    	echo "BreadDog出品，电报：https://t.me/breaddog"
    	echo "最低配置：2C4G150G，推荐配置：4C8G300G"
        echo "请选择要执行的操作:"
        echo "1. 部署节点"
        echo "2. 创建钱包"
        echo "3. 导入钱包"
        echo "4. 查看余额"
        echo "5. 同步状态"    
        echo "6. 创建验证者"
        echo "7. 查看当前服务状态"
        echo "8. 运行日志查询"
        echo "9. 删除节点"
        echo "10. 质押代币"  
        echo "0. 退出脚本exit"
        read -r -p "请输入选项: " OPTION
    
        case $OPTION in
        1) install_node ;;
        2) add_wallet ;;
        3) import_wallet ;;
        4) check_balances ;;
        5) check_sync_status ;;    
        6) add_validator ;;
        7) check_service_status ;;
        8) view_logs ;;
        9) uninstall_node ;;
        10) delegate_stake ;;  
        0) echo "退出脚本。"; exit 0 ;;
        *) echo "无效选项，请重新输入。"; sleep 3 ;;
        esac
        echo "按任意键返回主菜单..."
        read -n 1
    done
}

# 显示主菜单
main_menu
