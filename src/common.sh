#!/usr/bin/env bash
# Fixed != operators 2025-01-29

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
    status=$(dpkg-query -W -f='${db:Status-Abbrev}' "$package" )

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
    status=$(dpkg-query -W -f='${db:Status-Abbrev}' "$package" )

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
    
    # Run daemon-reload first if requested, especially important for Quadlet-generated services
    # For check action, only reload if unit file appears missing (might be newly generated)
    if [ "$daemon_reload" = "true" ]; then
        if [ "$action" != "check" ]; then
            sudo systemctl daemon-reload || true
        else
            # For check action, do a quick check first
            local unit_file_check=false
            if systemctl list-unit-files --no-pager --no-legend "$unit_name" 2>/dev/null | grep -q "$unit_name"; then
                unit_file_check=true
            fi
            
            # If unit file missing but daemon-reload requested, try reload and check again
            if [ "$unit_file_check" = false ]; then
                sudo systemctl daemon-reload || true
            fi
        fi
    fi
    
    # Check if unit file exists
    local unit_file_exists=false
    if systemctl list-unit-files --no-pager --no-legend "$unit_name" 2>/dev/null | grep -q "$unit_name"; then
        unit_file_exists=true
    fi
    
    # Get current enabled state
    local current_enabled_state="unknown"
    if [ "$unit_file_exists" = true ]; then
        # Capture only stdout, ignore stderr completely
        current_enabled_state=$(systemctl is-enabled "$unit_name" 2>/dev/null || true)
        # If empty or multiline, set to unknown
        if [ -z "$current_enabled_state" ] || [[ "$current_enabled_state" == *$'\n'* ]]; then
            current_enabled_state="unknown"
        fi
    fi
    
    # Get current active state
    local current_active_state="unknown"
    if [ "$unit_file_exists" = true ]; then
        # Capture only stdout, ignore stderr completely  
        current_active_state=$(systemctl is-active "$unit_name" 2>/dev/null || true)
        # If empty or multiline, set to unknown
        if [ -z "$current_active_state" ] || [[ "$current_active_state" == *$'\n'* ]]; then
            current_active_state="unknown"
        fi
    fi
    
    if [ "$action" == "check" ]; then
        case "$state_type" in
            enabled)
                if [ "$unit_file_exists" = false ]; then
                    echo "unit file missing"
                elif [ "$auto_start" = "true" ] && [ "${current_enabled_state}" != "enabled" ]; then
                    echo "needs enabling"
                elif [ "$active" = "true" ] && [ "${current_active_state}" != "active" ]; then
                    echo "needs start"
                else
                    echo "ok"
                fi
                ;;
            disabled)
                if [ "$unit_file_exists" = false ]; then
                    echo "unit file missing"
                elif [ "${current_enabled_state}" != "disabled" ]; then
                    echo "needs disabling"
                elif [ "$stop_if_running" = "true" ] && [ "${current_active_state}" = "active" ]; then
                    echo "needs stop"
                else
                    echo "ok"
                fi
                ;;
            masked)
                # For masked state, we need to check if the symlink exists
                local unit_path="/etc/systemd/system/$unit_name"
                if [ -L "$unit_path" ] && [ "$(readlink "$unit_path")" = "/dev/null" ]; then
                    echo "ok"
                else
                    echo "needs masking"
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
                    if [ "${current_enabled_state}" != "enabled" ]; then
                        echo "Unit enablement state:"
                        echo "  Current:  $current_enabled_state"
                        echo "  Expected: enabled"
                    fi
                    if [ "$active" = "true" ] && [ "${current_active_state}" != "active" ]; then
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
                    if [ "${current_enabled_state}" != "disabled" ]; then
                        echo "Unit enablement state:"
                        echo "  Current:  $current_enabled_state"
                        echo "  Expected: disabled"
                    fi
                    if [ "$stop_if_running" = "true" ] && [ "${current_active_state}" = "active" ]; then
                        echo "Unit active state:"
                        echo "  Current:  $current_active_state"
                        echo "  Expected: inactive"
                    fi
                fi
                ;;
            masked)
                if [ "$unit_file_exists" = false ]; then
                    echo "Unit file missing: $unit_name"
                elif [ "${current_enabled_state}" != "masked" ]; then
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
        
        case "$state_type" in
            enabled)
                # For Quadlet services, try to enable even if unit file appears missing
                # as daemon-reload might have generated it, but only if autoStart is true
                if [ "$unit_file_exists" = false ]; then
                    if [ "$auto_start" = "true" ]; then
                        # Try enabling anyway in case unit file was just generated
                        if sudo systemctl enable "$unit_name" ; then
                            changes="${changes}enabled "
                            unit_file_exists=true
                            # Refresh states after successful enable
                            current_enabled_state="enabled"
                            current_active_state=$(systemctl is-active "$unit_name" 2>&1 | head -1 || echo "unknown")
                        else
                            echo "unit file missing and cannot enable"
                            return
                        fi
                    else
                        # If autoStart is false, check if unit exists after daemon-reload
                        # Re-check unit file existence after daemon-reload
                        if systemctl list-unit-files --no-pager --no-legend "$unit_name" 2>/dev/null | grep -q "$unit_name"; then
                            unit_file_exists=true
                            current_enabled_state=$(systemctl is-enabled "$unit_name" 2>/dev/null || true)
                            if [ -z "$current_enabled_state" ] || [[ "$current_enabled_state" == *$'\n'* ]]; then
                                current_enabled_state="unknown"
                            fi
                            current_active_state=$(systemctl is-active "$unit_name" 2>/dev/null || true)
                            if [ -z "$current_active_state" ] || [[ "$current_active_state" == *$'\n'* ]]; then
                                current_active_state="unknown"
                            fi
                        else
                            echo "unit file missing"
                            return
                        fi
                    fi
                fi
                
                # Enable unit if needed and autoStart is true
                if [ "$auto_start" = "true" ] && [ "${current_enabled_state}" != "enabled" ]; then
                    sudo systemctl enable "$unit_name"
                    changes="${changes}enabled "
                fi
                
                # Start unit if needed
                if [ "$active" = "true" ] && [ "${current_active_state}" != "active" ]; then
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
                if [ "$stop_if_running" = "true" ] && [ "${current_active_state}" = "active" ]; then
                    sudo systemctl stop "$unit_name"
                    changes="${changes}stopped "
                fi
                
                # Disable unit if needed
                if [ "${current_enabled_state}" != "disabled" ]; then
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
                # Masking can be done even without a unit file
                # systemctl mask just creates a symlink to /dev/null
                local unit_path="/etc/systemd/system/$unit_name"
                
                # Check if already masked
                if [ -L "$unit_path" ] && [ "$(readlink "$unit_path")" = "/dev/null" ]; then
                    echo "ok"
                    return
                fi
                
                # If a real unit file exists (not a symlink), we need to move it first
                if [ -f "$unit_path" ] && [ ! -L "$unit_path" ]; then
                    # Move the real file to a backup location
                    sudo mv "$unit_path" "${unit_path}.pre-mask"
                fi
                
                # Now mask the unit (this creates a symlink to /dev/null)
                sudo systemctl mask "$unit_name"
                echo "updated (masked)"
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

# __user_present(action, name, uid, gid, comment, home, shell)
function __user_present() {
    local action=$1
    local name=$2
    local uid=$3
    local gid=$4
    local comment=$5
    local home=$6
    local shell=$7
    
    # Check if user exists
    if id "$name" >/dev/null 2>&1; then
        local current_uid
        current_uid=$(id -u "$name")
        local current_gid
        current_gid=$(id -g "$name")
        local current_home
        current_home=$(getent passwd "$name" | cut -d: -f6)
        local current_shell
        current_shell=$(getent passwd "$name" | cut -d: -f7)
        local current_comment
        current_comment=$(getent passwd "$name" | cut -d: -f5)
        
        if [ "$action" == "check" ]; then
            local needs_update=""
            if [ -n "$uid" ] && [ "$current_uid" != "$uid" ]; then
                needs_update="uid "
            fi
            if [ -n "$gid" ] && [ "$current_gid" != "$gid" ]; then
                needs_update="${needs_update}gid "
            fi
            if [ -n "$home" ] && [ "$current_home" != "$home" ]; then
                needs_update="${needs_update}home "
            fi
            if [ -n "$shell" ] && [ "$current_shell" != "$shell" ]; then
                needs_update="${needs_update}shell "
            fi
            if [ -n "$comment" ] && [ "$current_comment" != "$comment" ]; then
                needs_update="${needs_update}comment "
            fi
            
            if [ -n "$needs_update" ]; then
                echo "needs update ($needs_update)"
            else
                echo "ok"
            fi
        elif [ "$action" == "diff" ]; then
            local has_changes=false
            if [ -n "$uid" ] && [ "$current_uid" != "$uid" ]; then
                echo "UID differs:"
                echo "  Current:  $current_uid"
                echo "  Expected: $uid"
                has_changes=true
            fi
            if [ -n "$gid" ] && [ "$current_gid" != "$gid" ]; then
                echo "GID differs:"
                echo "  Current:  $current_gid"
                echo "  Expected: $gid"
                has_changes=true
            fi
            if [ -n "$home" ] && [ "$current_home" != "$home" ]; then
                echo "Home directory differs:"
                echo "  Current:  $current_home"
                echo "  Expected: $home"
                has_changes=true
            fi
            if [ -n "$shell" ] && [ "$current_shell" != "$shell" ]; then
                echo "Shell differs:"
                echo "  Current:  $current_shell"
                echo "  Expected: $shell"
                has_changes=true
            fi
            if [ -n "$comment" ] && [ "$current_comment" != "$comment" ]; then
                echo "Comment differs:"
                echo "  Current:  $current_comment"
                echo "  Expected: $comment"
                has_changes=true
            fi
            if [ "$has_changes" = false ]; then
                echo ""
            fi
        elif [ "$action" == "apply" ]; then
            local changes=""
            
            if [ -n "$uid" ] && [ "$current_uid" != "$uid" ]; then
                sudo usermod -u "$uid" "$name"
                changes="${changes}uid "
            fi
            if [ -n "$gid" ] && [ "$current_gid" != "$gid" ]; then
                sudo usermod -g "$gid" "$name"
                changes="${changes}gid "
            fi
            if [ -n "$home" ] && [ "$current_home" != "$home" ]; then
                sudo usermod -d "$home" "$name"
                changes="${changes}home "
            fi
            if [ -n "$shell" ] && [ "$current_shell" != "$shell" ]; then
                sudo usermod -s "$shell" "$name"
                changes="${changes}shell "
            fi
            if [ -n "$comment" ] && [ "$current_comment" != "$comment" ]; then
                sudo usermod -c "$comment" "$name"
                changes="${changes}comment "
            fi
            
            
            if [ -n "$changes" ]; then
                echo "updated ($changes)"
            else
                echo "ok"
            fi
        else
            todo "$action is not implemented for user_present"
        fi
    else
        if [ "$action" == "check" ]; then
            echo "needs creation"
        elif [ "$action" == "diff" ]; then
            echo "User does not exist, will be created:"
            echo "  Name: $name"
            if [ -n "$uid" ]; then
                echo "  UID: $uid"
            fi
            if [ -n "$gid" ]; then
                echo "  GID: $gid"
            fi
            if [ -n "$home" ]; then
                echo "  Home: $home"
            fi
            echo "  Shell: $shell"
            if [ -n "$comment" ]; then
                echo "  Comment: $comment"
            fi
        elif [ "$action" == "apply" ]; then
            local useradd_cmd=("sudo" "useradd")
            
            if [ -n "$uid" ]; then
                useradd_cmd+=("-u" "$uid")
            fi
            if [ -n "$gid" ]; then
                useradd_cmd+=("-g" "$gid")
            fi
            if [ -n "$home" ]; then
                useradd_cmd+=("-d" "$home")
            fi
            if [ -n "$shell" ]; then
                useradd_cmd+=("-s" "$shell")
            else
                useradd_cmd+=("-s" "/usr/sbin/nologin")
            fi
            if [ -n "$comment" ]; then
                useradd_cmd+=("-c" "$comment")
            fi
            
            # Create home directory by default
            useradd_cmd+=("-m")
            
            # Add the username
            useradd_cmd+=("$name")
            
            # Execute the command
            "${useradd_cmd[@]}"
            
            echo "created"
        else
            todo "$action is not implemented for missing user_present"
        fi
    fi
}

# __user_absent(action, name)
function __user_absent() {
    local action=$1
    local name=$2
    
    if id "$name" >/dev/null 2>&1; then
        if [ "$action" == "check" ]; then
            echo "needs removal"
        elif [ "$action" == "diff" ]; then
            echo "User exists, will be removed: $name"
        elif [ "$action" == "apply" ]; then
            sudo userdel "$name"
            echo "removed"
        else
            todo "$action is not implemented for user_absent"
        fi
    else
        if [ "$action" == "check" ]; then
            echo "ok"
        elif [ "$action" == "diff" ]; then
            echo ""
        elif [ "$action" == "apply" ]; then
            echo "ok"
        else
            todo "$action is not implemented for user_absent"
        fi
    fi
}

# __group_present(action, name, gid, members)
function __group_present() {
    local action=$1
    local name=$2
    local gid=$3
    local members=$4
    
    if getent group "$name" >/dev/null 2>&1; then
        local current_gid
        current_gid=$(getent group "$name" | cut -d: -f3)
        local current_members
        current_members=$(getent group "$name" | cut -d: -f4)
        
        if [ "$action" == "check" ]; then
            local needs_update=""
            if [ -n "$gid" ] && [ "$current_gid" != "$gid" ]; then
                needs_update="gid "
            fi
            if [ -n "$members" ] && [ "$current_members" != "$members" ]; then
                needs_update="${needs_update}members "
            fi
            
            if [ -n "$needs_update" ]; then
                echo "needs update ($needs_update)"
            else
                echo "ok"
            fi
        elif [ "$action" == "diff" ]; then
            local has_changes=false
            if [ -n "$gid" ] && [ "$current_gid" != "$gid" ]; then
                echo "GID differs:"
                echo "  Current:  $current_gid"
                echo "  Expected: $gid"
                has_changes=true
            fi
            if [ -n "$members" ] && [ "$current_members" != "$members" ]; then
                echo "Members differ:"
                echo "  Current:  $current_members"
                echo "  Expected: $members"
                has_changes=true
            fi
            if [ "$has_changes" = false ]; then
                echo ""
            fi
        elif [ "$action" == "apply" ]; then
            local changes=""
            
            if [ -n "$gid" ] && [ "$current_gid" != "$gid" ]; then
                sudo groupmod -g "$gid" "$name"
                changes="${changes}gid "
            fi
            
            if [ -n "$members" ] && [ "$current_members" != "$members" ]; then
                # Clear current members and add new ones
                sudo gpasswd -M "$members" "$name"
                changes="${changes}members "
            fi
            
            if [ -n "$changes" ]; then
                echo "updated ($changes)"
            else
                echo "ok"
            fi
        else
            todo "$action is not implemented for group_present"
        fi
    else
        if [ "$action" == "check" ]; then
            echo "needs creation"
        elif [ "$action" == "diff" ]; then
            echo "Group does not exist, will be created:"
            echo "  Name: $name"
            if [ -n "$gid" ]; then
                echo "  GID: $gid"
            fi
            if [ -n "$members" ]; then
                echo "  Members: $members"
            fi
        elif [ "$action" == "apply" ]; then
            if [ -n "$gid" ]; then
                sudo groupadd -g "$gid" "$name"
            else
                sudo groupadd "$name"
            fi
            
            # Add members if specified
            if [ -n "$members" ]; then
                sudo gpasswd -M "$members" "$name"
            fi
            
            echo "created"
        else
            todo "$action is not implemented for missing group_present"
        fi
    fi
}

# __group_absent(action, name)
function __group_absent() {
    local action=$1
    local name=$2
    
    if getent group "$name" >/dev/null 2>&1; then
        if [ "$action" == "check" ]; then
            echo "needs removal"
        elif [ "$action" == "diff" ]; then
            echo "Group exists, will be removed: $name"
        elif [ "$action" == "apply" ]; then
            sudo groupdel "$name"
            echo "removed"
        else
            todo "$action is not implemented for group_absent"
        fi
    else
        if [ "$action" == "check" ]; then
            echo "ok"
        elif [ "$action" == "diff" ]; then
            echo ""
        elif [ "$action" == "apply" ]; then
            echo "ok"
        else
            todo "$action is not implemented for group_absent"
        fi
    fi
}
