#!/usr/bin/env bash

function todo() {
    echo "NOT IMPLEMENTED (${BASH_SOURCE[1]}:${BASH_LINENO[0]}): $*" >&2
    exit 42
}

# __apt_package(action, package, state, updateBeforeInstall)
function __apt_package() {
    local action=$1
    shift
    local package=$1
    shift
    local state=$1
    shift
    local update=$1
    shift

    local status
    status=$(dpkg-query -W -f='${db:Status-Abbrev}' "$package" 2>/dev/null)

    if [ "$state" == "installed" ]; then
        if [ "$status" != "ii " ]; then
            if [ "$action" == "check" ]; then
                echo "missing"
            elif [ "$action" == "diff" ]; then
                echo "desired = installed, actual = missing"
            elif [ "$action" == "apply" ]; then
                if [ "$update" == "true" ]; then
                    sudo apt-get update
                fi
                sudo apt-get install -y --no-upgrade --no-install-recommends "$package"
            else
                todo "$action is not implemented for present packages"
            fi
        else
            if [ "$action" == "check" ]; then
                echo "ok"
            elif [ "$action" == "diff" ]; then
                echo ""
            elif [ "$action" == "apply" ]; then
                echo "ok"
            else
                todo "$action is not implemented for present packages"
            fi
        fi
    elif [ "$state" == "missing" ]; then
        if [ "$status" != "" ]; then
            if [ "$action" == "check" ]; then
                echo "$status"
            elif [ "$action" == "apply" ]; then
                sudo apt-get remove -y "$package"
            else
                todo $action is not implemented
            fi
        else
            if [ "$action" == "check" ]; then
                echo "ok"
            elif [ "$action" == "apply" ]; then
                echo "ok"
            else
                todo "$action is not implemented for missing packages"
            fi
        fi
    else
        todo "$action $package $state $status"
    fi
}

function __fs_file() {
    local action=$1
    shift
    local path=$1
    shift
    local state=$1
    shift

    if [ "$state" == "present" ]; then
        local expectedHash=$1
        shift
        local expectedOwner=$1
        shift
        local expectedGroup=$1
        shift
        local expectedPermissions=$1
        shift
        
        local contentFunction="__content__$expectedHash"

        if test -f "$path"; then
            local hash=""
            read -r hash _ < <(sudo sha256sum "$path")
            local owner
            owner=$(sudo stat --printf="%U" "$path")
            local group
            group=$(sudo stat --printf="%G" "$path")
            local permissions
            permissions=$(sudo stat --printf="%a" "$path")

            if [ "$action" == "check" ]; then
                if [ "$hash" != "$expectedHash" ]; then
                    echo "content: $hash != $expectedHash"
                    exit
                fi
                if [ "$owner" != "$expectedOwner" ]; then
                    echo "owner: $owner != $expectedOwner"
                    exit
                fi

                if [ "$group" != "$expectedGroup" ]; then
                    echo "group: $group != $expectedGroup"
                    exit
                fi

                if [ "$permissions" != "$expectedPermissions" ]; then
                    echo "permissions: $permissions != $expectedPermissions"
                    exit
                fi

                echo "ok"
            elif [ "$action" == "diff" ]; then
                if [ "$hash" != "$expectedHash" ]; then
                    echo "content: $hash != $expectedHash"
                    local tmp
                    tmp=$(mktemp)
                    "$contentFunction" > "$tmp"
                    sudo diff "$path" "$tmp"
                fi
                if [ "$owner" != "$expectedOwner" ]; then
                    echo "owner: $owner != $expectedOwner"
                fi

                if [ "$group" != "$expectedGroup" ]; then
                    echo "group: $group != $expectedGroup"
                fi

                if [ "$permissions" != "$expectedPermissions" ]; then
                    echo "permissions: $permissions != $expectedPermissions"
                fi
            elif [ "$action" == "apply" ]; then
                if [ "$hash" != "$expectedHash" ]; then
                    local tmp
                    tmp=$(mktemp)
                    "$contentFunction" > "$tmp"
                    cat "$tmp" | sudo tee "$path" > /dev/null
                    echo "content"
                fi

                if [ "$owner" != "$expectedOwner" ]; then
                    sudo chown $expectedOwner "$path"
                    echo "owner: $owner"
                fi

                if [ "$group" != "$expectedGroup" ]; then
                    sudo chgrp $expectedGroup "$path"
                    echo "group: $group"
                fi

                if [ "$permissions" != "$expectedPermissions" ]; then
                    sudo chmod $expectedPermissions "$path"
                    echo "permissions: $permissions"
                fi                 

                echo "ok"       
            else
                todo $action is not implemented for present files
            fi
        else
            if [ "$action" == "check" ]; then
                echo "missing"
            elif [ "$action" == "apply" ]; then
                todo "$action $path $state $expectedHash $expectedOwner $expectedGroup $expectedPermissions"
                # \(contentFunctionName)
                # sudo chown $expectedOwner "$path"
                # sudo chgrp $expectedGroup "$path"
                # sudo chmod $expectedPermissions "$path"
                # echo "$expectedHash"
            else
                todo $action is not implemented for missing files
            fi
        fi
    elif [ "$state" == "missing" ]; then
        todo "$action $path $state"
    else
        todo "$action $path $state"
    fi
}