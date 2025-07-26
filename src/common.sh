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
                sudo DEBIAN_FRONTEND=noninteractive apt-get update
            fi
            sudo DEBIAN_FRONTEND=noninteractive apt-get install -y --no-upgrade --no-install-recommends "$package"
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
            sudo DEBIAN_FRONTEND=noninteractive apt-get remove -y "$package"
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
            local hasChanges=false
            if [ "$hash" != "$expectedHash" ]; then
                echo "Content differs:"
                echo "  Current hash:  $hash"
                echo "  Expected hash: $expectedHash"
                echo "  File size: $(sudo cat "$path" | wc -c) bytes"
                echo "  Expected size: $("$contentFunction" | wc -c) bytes"
                local tmp
                tmp=$(mktemp)
                "$contentFunction" > "$tmp"
                echo "  Content diff:"
                sudo diff -u "$path" "$tmp" || true
                rm "$tmp"
                hasChanges=true
            fi
            if [ "$owner" != "$expectedOwner" ]; then
                echo "Owner differs:"
                echo "  Current:  $owner"
                echo "  Expected: $expectedOwner"
                hasChanges=true
            fi
            if [ "$group" != "$expectedGroup" ]; then
                echo "Group differs:"
                echo "  Current:  $group"
                echo "  Expected: $expectedGroup"
                hasChanges=true
            fi
            if [ "$permissions" != "$expectedPermissions" ]; then
                echo "Permissions differ:"
                echo "  Current:  $permissions"
                echo "  Expected: $expectedPermissions"
                hasChanges=true
            fi
            if [ "$hasChanges" = false ]; then
                echo ""
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
            echo "File does not exist, will be created:"
            echo "  Path: $path"
            echo "  Expected owner: $expectedOwner"
            echo "  Expected group: $expectedGroup"
            echo "  Expected permissions: $expectedPermissions"
            echo "  Expected hash: $expectedHash"
            echo "  Expected size: $("$contentFunction" | wc -c) bytes"
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
# __systemd_unit_present(action, unit_name, state_type, daemon_reload, active, auto_start, stop_if_running)
function __systemd_unit_present() {
    local action=$1
    local unit_name=$2
    local state_type=$3
    local daemon_reload=$4
    local active=$5
    # shellcheck disable=SC2034
    local auto_start=$6  # Used in conditional logic below
    local stop_if_running=$7
    
    # Check if unit file exists
    local unit_file_exists=false
    if systemctl list-unit-files --no-pager --no-legend "$unit_name" 2>/dev/null  < /dev/null |  grep -q "$unit_name"; then
        unit_file_exists=true
    fi
    
    # Get current enabled state
    local current_enabled_state="unknown"
    if [ "$unit_file_exists" = true ]; then
        current_enabled_state=$(systemctl is-enabled "$unit_name" 2>/dev/null || echo "unknown")
    fi
    
    # Get current active state
    local current_active_state="unknown"
    if [ "$unit_file_exists" = true ]; then
        current_active_state=$(systemctl is-active "$unit_name" 2>/dev/null || echo "unknown")
    fi
    
    if [ "$action" == "check" ]; then
        case "$state_type" in
            enabled)
                if [ "$unit_file_exists" = false ]; then
                    echo "unit file missing"
                elif [ "$current_enabled_state" \!= "enabled" ]; then
                    echo "needs enabling"
                elif [ "$active" = "true" ] && [ "$current_active_state" \!= "active" ]; then
                    echo "needs start"
                else
                    echo "ok"
                fi
                ;;
            disabled)
                if [ "$unit_file_exists" = false ]; then
                    echo "unit file missing"
                elif [ "$current_enabled_state" \!= "disabled" ]; then
                    echo "needs disabling"
                elif [ "$stop_if_running" = "true" ] && [ "$current_active_state" = "active" ]; then
                    echo "needs stop"
                else
                    echo "ok"
                fi
                ;;
            masked)
                if [ "$unit_file_exists" = false ]; then
                    echo "unit file missing"
                elif [ "$current_enabled_state" \!= "masked" ]; then
                    echo "needs masking"
                else
                    echo "ok"
                fi
                ;;
            missing)
                if [ "$unit_file_exists" = true ]; then
                    echo "needs removal"
                else
                    echo "ok"
                fi
                ;;
        esac
    elif [ "$action" == "diff" ]; then
        case "$state_type" in
            enabled)
                if [ "$unit_file_exists" = false ]; then
                    echo "Unit file missing: $unit_name"
                else
                    if [ "$current_enabled_state" \!= "enabled" ]; then
                        echo "Unit enablement state:"
                        echo "  Current:  $current_enabled_state"
                        echo "  Expected: enabled"
                    fi
                    if [ "$active" = "true" ] && [ "$current_active_state" \!= "active" ]; then
                        echo "Unit active state:"
                        echo "  Current:  $current_active_state"
                        echo "  Expected: active"
                    fi
                fi
                ;;
            disabled)
                if [ "$unit_file_exists" = false ]; then
                    echo "Unit file missing: $unit_name"
                else
                    if [ "$current_enabled_state" \!= "disabled" ]; then
                        echo "Unit enablement state:"
                        echo "  Current:  $current_enabled_state"
                        echo "  Expected: disabled"
                    fi
                    if [ "$stop_if_running" = "true" ] && [ "$current_active_state" = "active" ]; then
                        echo "Unit active state:"
                        echo "  Current:  $current_active_state"
                        echo "  Expected: inactive"
                    fi
                fi
                ;;
            masked)
                if [ "$unit_file_exists" = false ]; then
                    echo "Unit file missing: $unit_name"
                elif [ "$current_enabled_state" \!= "masked" ]; then
                    echo "Unit enablement state:"
                    echo "  Current:  $current_enabled_state"
                    echo "  Expected: masked"
                fi
                ;;
            missing)
                if [ "$unit_file_exists" = true ]; then
                    echo "Unit exists but should be removed: $unit_name"
                fi
                ;;
        esac
    elif [ "$action" == "apply" ]; then
        local changes=""
        
        # Run daemon-reload if requested
        if [ "$daemon_reload" = "true" ] && [ "$unit_file_exists" = true ]; then
            sudo systemctl daemon-reload
        fi
        
        case "$state_type" in
            enabled)
                if [ "$unit_file_exists" = false ]; then
                    echo "unit file missing"
                    return
                fi
                
                # Enable unit if needed
                if [ "$current_enabled_state" \!= "enabled" ]; then
                    sudo systemctl enable "$unit_name"
                    changes="${changes}enabled "
                fi
                
                # Start unit if needed
                if [ "$active" = "true" ] && [ "$current_active_state" \!= "active" ]; then
                    sudo systemctl start "$unit_name"
                    changes="${changes}started "
                fi
                
                if [ -n "$changes" ]; then
                    echo "updated ($changes)"
                else
                    echo "ok"
                fi
                ;;
            disabled)
                if [ "$unit_file_exists" = false ]; then
                    echo "unit file missing"
                    return
                fi
                
                # Stop unit if needed
                if [ "$stop_if_running" = "true" ] && [ "$current_active_state" = "active" ]; then
                    sudo systemctl stop "$unit_name"
                    changes="${changes}stopped "
                fi
                
                # Disable unit if needed
                if [ "$current_enabled_state" \!= "disabled" ]; then
                    sudo systemctl disable "$unit_name"
                    changes="${changes}disabled "
                fi
                
                if [ -n "$changes" ]; then
                    echo "updated ($changes)"
                else
                    echo "ok"
                fi
                ;;
            masked)
                if [ "$unit_file_exists" = false ]; then
                    echo "unit file missing"
                    return
                fi
                
                # Mask unit if needed
                if [ "$current_enabled_state" \!= "masked" ]; then
                    sudo systemctl mask "$unit_name"
                    changes="${changes}masked "
                fi
                
                if [ -n "$changes" ]; then
                    echo "updated ($changes)"
                else
                    echo "ok"
                fi
                ;;
            missing)
                # This state type would be used for cleanup
                # For now, we don't remove unit files
                echo "ok"
                ;;
        esac
    else
        todo "$action is not implemented for systemd_unit_present"
    fi
}
