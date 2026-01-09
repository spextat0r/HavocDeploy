#!/bin/bash

echo "Installing Repos"
sudo apt update
sudo apt install -y git build-essential apt-utils cmake libfontconfig1 libglu1-mesa-dev libgtest-dev libspdlog-dev libboost-all-dev libncurses5-dev libgdbm-dev libssl-dev libreadline-dev libffi-dev libsqlite3-dev libbz2-dev mesa-common-dev qtbase5-dev qtchooser qt5-qmake qtbase5-dev-tools libqt5websockets5 libqt5websockets5-dev qtdeclarative5-dev golang-go qtbase5-dev libqt5websockets5-dev python3-dev libboost-all-dev mingw-w64 nasm

if [[ $? -ne 0 ]] ; then
    echo "Download of repos Failed"
    exit 1
fi

echo "Repos downloaded successfully"

echo "Downloading Havoc"

git clone https://github.com/HavocFramework/Havoc.git

if [[ $? -ne 0 ]] ; then
    echo "Download Failed"
    exit 1
fi

echo "Download complete"

if [ ! -d "./Havoc/" ]; then
    echo "Cannot find Havoc folder"
    exit 1
fi

cd ./Havoc/

read -r -d '' makefiledata << EOF
ifndef VERBOSE
.SILENT:
endif

# main build target. compiles the teamserver and client
all: ts-build client-build

# teamserver building target
ts-build:
	@ echo "[*] building teamserver"
	@ ./teamserver/Install.sh
	@ find . -type f -exec sed -i 's/0x[dD][eE][aA][dD][bB][eE][eE][fF]/0xREPLACEME/g' {} + 2>/dev/null
	@ cd teamserver; GO111MODULE="on" go build -ldflags="-s -w -X cmd.VersionCommit=$(git rev-parse HEAD)" -o ../havoc main.go
	@ sudo setcap 'cap_net_bind_service=+ep' havoc # this allows you to run the server as a regular user

dev-ts-compile:
	@ echo "[*] compile teamserver"
	@ cd teamserver; GO111MODULE="on" go build -ldflags="-s -w -X cmd.VersionCommit=$(git rev-parse HEAD)" -o ../havoc main.go 

ts-cleanup: 
	@ echo "[*] teamserver cleanup"
	@ rm -rf ./teamserver/bin
	@ rm -rf ./data/loot
	@ rm -rf ./data/x86_64-w64-mingw32-cross 
	@ rm -rf ./data/havoc.db
	@ rm -rf ./data/server.*
	@ rm -rf ./teamserver/.idea
	@ rm -rf ./havoc

# client building and cleanup targets 
client-build: 
	@ echo "[*] building client"
	@ git submodule update --init --recursive
	@ find . -type f -exec sed -i 's/0x[dD][eE][aA][dD][bB][eE][eE][fF]/0xREPLACEME/g' {} + 2>/dev/null
	@ mkdir client/Build; cd client/Build; cmake ..
	@ if [ -d "client/Modules" ]; then echo "Modules installed"; else git clone https://github.com/HavocFramework/Modules client/Modules --single-branch --branch `git rev-parse --abbrev-ref HEAD`; fi
	@ find . -type f -exec sed -i 's/0x[dD][eE][aA][dD][bB][eE][eE][fF]/0xREPLACEME/g' {} + 2>/dev/null
	@ cmake --build client/Build -- -j 4

client-cleanup:
	@ echo "[*] client cleanup"
	@ rm -rf ./client/Build
	@ rm -rf ./client/Bin/*
	@ rm -rf ./client/Data/database.db
	@ rm -rf ./client/.idea
	@ rm -rf ./client/cmake-build-debug
	@ rm -rf ./client/Havoc
	@ rm -rf ./client/Modules


# cleanup target 
clean: ts-cleanup client-cleanup
	@ rm -rf ./data/*.db
	@ rm -rf payloads/Demon/.idea
EOF


echo "Generating random magic value"

rand=$(tr -dc 'a-f0-9' </dev/urandom | head -c 8)

if [[ $? -ne 0 ]] ; then
    echo "Generating random value failed"
    exit 1
fi

echo "Random magic value = 0x$rand"


makefiledata_replaced="${makefiledata//REPLACEME/$rand}"

echo -e "$makefiledata_replaced" > makefile

sudo make all
