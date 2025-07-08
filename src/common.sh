#!/usr/bin/env bash

function todo() {
    echo "NOT IMPLEMENTED (${BASH_SOURCE[1]}:${BASH_LINENO[0]}): $*" >&2
    exit 42
}

# __apt_installed(action, package, updateBeforeInstall)
function __apt_installed() {
    local action=$1
    local package=$2
    local update=$3

    local status
    status=$(dpkg-query -W -f='${db:Status-Abbrev}' "$package" 2>/dev/null)

    if [ "$status" != "ii " ]; then
        if [ "$action" == "check" ]; then
            echo "not installed"
        elif [ "$action" == "diff" ]; then
            echo "Package will be installed: $package"
        elif [ "$action" == "apply" ]; then
            if [ "$update" == "true" ]; then
                sudo apt-get update
            fi
            sudo apt-get install -y --no-upgrade --no-install-recommends "$package"
            echo "installed"
        else
            todo "$action is not implemented for apt_installed"
        fi
    else
        if [ "$action" == "check" ]; then
            echo "ok"
        elif [ "$action" == "diff" ]; then
            echo ""
        elif [ "$action" == "apply" ]; then
            echo "ok"
        else
            todo "$action is not implemented for apt_installed"
        fi
    fi
}

# __apt_missing(action, package)
function __apt_missing() {
    local action=$1
    local package=$2

    local status
    status=$(dpkg-query -W -f='${db:Status-Abbrev}' "$package" 2>/dev/null)

    if [ "$status" != "" ]; then
        if [ "$action" == "check" ]; then
            echo "installed (needs removal)"
        elif [ "$action" == "diff" ]; then
            echo "Package will be removed: $package"
        elif [ "$action" == "apply" ]; then
            sudo apt-get remove -y "$package"
            echo "removed"
        else
            todo "$action is not implemented for apt_missing"
        fi
    else
        if [ "$action" == "check" ]; then
            echo "ok"
        elif [ "$action" == "diff" ]; then
            echo ""
        elif [ "$action" == "apply" ]; then
            echo "ok"
        else
            todo "$action is not implemented for apt_missing"
        fi
    fi
}

# __file_present(action, path, expectedHash, expectedOwner, expectedGroup, expectedPermissions)
function __file_present() {
    local action=$1
    local path=$2
    local expectedHash=$3
    local expectedOwner=$4
    local expectedGroup=$5
    local expectedPermissions=$6
    
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
                echo "needs update (content)"
                return
            fi
            if [ "$owner" != "$expectedOwner" ]; then
                echo "needs update (owner)"
                return
            fi
            if [ "$group" != "$expectedGroup" ]; then
                echo "needs update (group)"
                return
            fi
            if [ "$permissions" != "$expectedPermissions" ]; then
                echo "needs update (permissions)"
                return
            fi
            echo "ok"
        elif [ "$action" == "diff" ]; then
            if [ "$hash" != "$expectedHash" ]; then
                echo "Content differs:"
                local tmp
                tmp=$(mktemp)
                "$contentFunction" > "$tmp"
                sudo diff "$path" "$tmp" || true
            fi
            if [ "$owner" != "$expectedOwner" ]; then
                echo "Owner: $owner -> $expectedOwner"
            fi
            if [ "$group" != "$expectedGroup" ]; then
                echo "Group: $group -> $expectedGroup"
            fi
            if [ "$permissions" != "$expectedPermissions" ]; then
                echo "Permissions: $permissions -> $expectedPermissions"
            fi
        elif [ "$action" == "apply" ]; then
            local changes=""
            if [ "$hash" != "$expectedHash" ]; then
                local tmp
                tmp=$(mktemp)
                "$contentFunction" > "$tmp"
                sudo cp "$tmp" "$path"
                rm "$tmp"
                changes="content "
            fi
            if [ "$owner" != "$expectedOwner" ]; then
                sudo chown "$expectedOwner" "$path"
                changes="${changes}owner "
            fi
            if [ "$group" != "$expectedGroup" ]; then
                sudo chgrp "$expectedGroup" "$path"
                changes="${changes}group "
            fi
            if [ "$permissions" != "$expectedPermissions" ]; then
                sudo chmod "$expectedPermissions" "$path"
                changes="${changes}permissions "
            fi
            
            if [ -n "$changes" ]; then
                echo "updated ($changes)"
            else
                echo "ok"
            fi
        else
            todo "$action is not implemented for file_present"
        fi
    else
        if [ "$action" == "check" ]; then
            echo "needs creation"
        elif [ "$action" == "diff" ]; then
            echo "File does not exist, will be created"
        elif [ "$action" == "apply" ]; then
            # Create directory if it doesn't exist
            local dir
            dir=$(dirname "$path")
            sudo mkdir -p "$dir"
            
            # Create file with content
            local tmp
            tmp=$(mktemp)
            "$contentFunction" > "$tmp"
            sudo cp "$tmp" "$path"
            rm "$tmp"
            
            # Set ownership and permissions
            sudo chown "$expectedOwner" "$path"
            sudo chgrp "$expectedGroup" "$path"
            sudo chmod "$expectedPermissions" "$path"
            
            echo "created"
        else
            todo "$action is not implemented for missing file_present"
        fi
    fi
}

# __file_missing(action, path)
function __file_missing() {
    local action=$1
    local path=$2

    if test -f "$path"; then
        if [ "$action" == "check" ]; then
            echo "needs removal"
        elif [ "$action" == "diff" ]; then
            echo "File exists, will be removed"
        elif [ "$action" == "apply" ]; then
            sudo rm -f "$path"
            echo "removed"
        else
            todo "$action is not implemented for file_missing"
        fi
    else
        if [ "$action" == "check" ]; then
            echo "ok"
        elif [ "$action" == "diff" ]; then
            echo ""
        elif [ "$action" == "apply" ]; then
            echo "ok"
        else
            todo "$action is not implemented for file_missing"
        fi
    fi
}

# __dir_present(action, path, expectedOwner, expectedGroup, expectedPermissions)
function __dir_present() {
    local action=$1
    local path=$2
    local expectedOwner=$3
    local expectedGroup=$4
    local expectedPermissions=$5

    if test -d "$path"; then
        local owner
        owner=$(sudo stat --printf="%U" "$path")
        local group
        group=$(sudo stat --printf="%G" "$path")
        local permissions
        permissions=$(sudo stat --printf="%a" "$path")

        if [ "$action" == "check" ]; then
            if [ "$owner" != "$expectedOwner" ]; then
                echo "needs update (owner)"
                return
            fi
            if [ "$group" != "$expectedGroup" ]; then
                echo "needs update (group)"
                return
            fi
            if [ "$permissions" != "$expectedPermissions" ]; then
                echo "needs update (permissions)"
                return
            fi
            echo "ok"
        elif [ "$action" == "diff" ]; then
            if [ "$owner" != "$expectedOwner" ]; then
                echo "Owner: $owner -> $expectedOwner"
            fi
            if [ "$group" != "$expectedGroup" ]; then
                echo "Group: $group -> $expectedGroup"
            fi
            if [ "$permissions" != "$expectedPermissions" ]; then
                echo "Permissions: $permissions -> $expectedPermissions"
            fi
        elif [ "$action" == "apply" ]; then
            local changes=""
            if [ "$owner" != "$expectedOwner" ]; then
                sudo chown "$expectedOwner" "$path"
                changes="${changes}owner "
            fi
            if [ "$group" != "$expectedGroup" ]; then
                sudo chgrp "$expectedGroup" "$path"
                changes="${changes}group "
            fi
            if [ "$permissions" != "$expectedPermissions" ]; then
                sudo chmod "$expectedPermissions" "$path"
                changes="${changes}permissions "
            fi
            
            if [ -n "$changes" ]; then
                echo "updated ($changes)"
            else
                echo "ok"
            fi
        else
            todo "$action is not implemented for dir_present"
        fi
    else
        if [ "$action" == "check" ]; then
            echo "needs creation"
        elif [ "$action" == "diff" ]; then
            echo "Directory does not exist, will be created"
        elif [ "$action" == "apply" ]; then
            # Create directory
            sudo mkdir -p "$path"
            
            # Set ownership and permissions
            sudo chown "$expectedOwner" "$path"
            sudo chgrp "$expectedGroup" "$path"
            sudo chmod "$expectedPermissions" "$path"
            
            echo "created"
        else
            todo "$action is not implemented for missing dir_present"
        fi
    fi
}

# __dir_missing(action, path)
function __dir_missing() {
    local action=$1
    local path=$2

    if test -d "$path"; then
        if [ "$action" == "check" ]; then
            echo "needs removal"
        elif [ "$action" == "diff" ]; then
            echo "Directory exists, will be removed"
        elif [ "$action" == "apply" ]; then
            sudo rm -rf "$path"
            echo "removed"
        else
            todo "$action is not implemented for dir_missing"
        fi
    else
        if [ "$action" == "check" ]; then
            echo "ok"
        elif [ "$action" == "diff" ]; then
            echo ""
        elif [ "$action" == "apply" ]; then
            echo "ok"
        else
            todo "$action is not implemented for dir_missing"
        fi
    fi
}