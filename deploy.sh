#!/bin/bash

# If you are using this on an ec2 instance use at least a t2.medium when building since havoc's compile stalls on a t2 or t3 micro

usage() {
    echo "Usage: $0 [-m <8-char hex string (a-f, 0-9)>] (if -m is omitted a random value will be used)"
    exit 1
}

# Parse options
while getopts ":m:" opt; do
    case "$opt" in
        m)
            MVAL="$OPTARG"
            ;;
        *)
            usage
            ;;
    esac
done

# If -m not provided, generate one
if [[ -z "$MVAL" ]]; then
    echo "Generating random magic value"

	rand=$(tr -dc 'a-f0-9' </dev/urandom | head -c 8)

	if [[ $? -ne 0 ]] ; then
		echo "Generating random value failed"
		exit 1
	fi

	echo "Random magic value = 0x$rand"
else
	if [[ ! "$MVAL" =~ ^[a-f0-9]{8}$ ]]; then
		echo "Error: -m must be exactly 8 characters long and contain only a-f and 0-9"
		exit 1
	fi
	rand=$MVAL
	echo "Static magic set by user magic value = 0x$rand"

fi



echo "Installing Repos"
sudo apt update
sudo apt install -y git build-essential apt-utils cmake libfontconfig1 libglu1-mesa-dev libgtest-dev libspdlog-dev libboost-all-dev libncurses5-dev libgdbm-dev libssl-dev libreadline-dev libffi-dev libsqlite3-dev libbz2-dev mesa-common-dev qtbase5-dev qtchooser qt5-qmake qtbase5-dev-tools libqt5websockets5 libqt5websockets5-dev qtdeclarative5-dev golang-go qtbase5-dev libqt5websockets5-dev python3-dev libboost-all-dev mingw-w64 nasm openssl

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

# Put the makefile into a variable
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


# Replace the text within makefile
makefiledata_replaced="${makefiledata//REPLACEME/$rand}"

# Save makefile to a file
echo -e "$makefiledata_replaced" > makefile

echo "Starting build."

# Build it
sudo make all

echo "Build complete."
# Save magic value to a file
echo -e "Magic value: 0x$rand" > magicvalue

echo "\n\nGenerating certs and config\n\n"

# Read our config to a variable
read -r -d '' configdata << EOF
Teamserver {
    Host = "0.0.0.0"
    Port = 40056

    Build {
        Compiler64 = "data/x86_64-w64-mingw32-cross/bin/x86_64-w64-mingw32-gcc"
        Compiler86 = "data/i686-w64-mingw32-cross/bin/i686-w64-mingw32-gcc"
        Nasm = "/usr/bin/nasm"
    }
}

Operators {
    user "5pider" {
        Password = "REPLACEMEPASSWORD"
    }

    user "Neo" {
        Password = "REPLACEMEPASSWORD"
    }
}


Demon {
    Sleep = 0
    Jitter = 0

    TrustXForwardedFor = false

    Injection {
        Spawn64 = "C:\\\\\\\\Windows:\\\\\\\\System32:\\\\\\\\notepad.exe"
        Spawn32 = "C:\\\\\\\\Windows:\\\\\\\\SysWOW64:\\\\\\\\notepad.exe"
    }
}

Listeners {
    Http {
        Name         = "listenhere"
        Hosts        = [
            "REPLACEMEIP"
        ]
        HostBind     = "0.0.0.0"
        PortBind     = 443
        PortConn     = 443
        HostRotation = "round-robin"
        Secure       = true
        UserAgent    = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.6357.0 Safari/537.36"
        

        Cert {
               Cert = "REPLACEMEPWD/customcert.crt"
               Key = "REPLACEMEPWD/customcert.key"
         }

        Headers = [
            "Content-type: text/plain",
            "Accept-Encoding: gzip",
            "Accept-Language: en-US,en;q=0.5",
            "cache-control: no-cache, no-store",
            "Sec-Fetch-Dest: empty",
            "Sec-Fetch-Mode: cors",
            "Sec-Fetch-Site: same-site"

        ]

        Response {
            Headers = [
                "Content-type: text/plain",
                "access-control-allow-headers: Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token,x-amzn-waf-bot-category,Panorama-Appentity",
                    "server: Microsoft-HTTPAPI/2.0"
            ]
        }
    }
}
EOF

# Replace all the things
randpassw=$(tr -dc 'a-f0-9' </dev/urandom | head -c 28)
myip=$(curl -s https://icanhazip.com)

configdata_replaced_PWD="${configdata//REPLACEMEPWD/$(pwd)}"

configdata_replaced_password="${configdata_replaced_PWD//REPLACEMEPASSWORD/$randpassw}"

configdata_replaced="${configdata_replaced_password//REPLACEMEIP/$myip}"

echo -e "$configdata_replaced" > $(pwd)/profiles/customprofile.yaoctl

# Generate a ssl certs
openssl genrsa -out $(pwd)/customcert.key 4096
if [[ $? -ne 0 ]] ; then
    echo "Error generating openssl certs"
    exit 1
fi
openssl req -new -key $(pwd)/customcert.key -out $(pwd)/customcert.csr
if [[ $? -ne 0 ]] ; then
    echo "Error generating openssl certs 1"
    exit 1
fi
openssl x509 -req -days 3650 -in $(pwd)/customcert.csr -signkey $(pwd)/customcert.key -out $(pwd)/customcert.crt
if [[ $? -ne 0 ]] ; then
    echo "Error generating openssl certs 2"
    exit 1
fi

# Check that the compilers exist if not add the symlink ourselves
if [ ! -f "$(pwd)/data/x86_64-w64-mingw32-cross/bin/x86_64-w64-mingw32-gcc" ] ; then
    echo "Cound not find compiler folder.. creating symlink"
	mkdir -p $(pwd)/data/x86_64-w64-mingw32-cross/bin
	ln -s $(which x86_64-w64-mingw32-gcc) $(pwd)/data/x86_64-w64-mingw32-cross/bin/x86_64-w64-mingw32-gcc
	if [[ $? -ne 0 ]] ; then
	    echo "Failed to create symlink!!!!"
	fi
fi

echo "Done"
