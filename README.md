# mkdir for RouterOS 6

This is a script that creates a `$mkdir` global variable containing a function. After running the script you will be able to create folders on your Mikrotik device by simply typing `$mkdir some/new/path`.

  - Easy to use
  - Functionality that was bafflingly left out
  - Should run on Router OS 6.2+ but much more testing is needed!

# Installation
## The Easy Way
Copy the `persist_create_mkdir_function.rsc` file to your Mikrotik device and then run `/import persist_create_mkdir_function.rsc`
This will create the function, as well as a new scheduler entry that will create the function on startup, ensuring `$mkdir` is always available to you and your scripts.

## The Even Easier Way
Copy and paste the below into your terminal to create the function and persist it using a scheduler startup script.
```
{
    :local result [/tool fetch \
    url="https://raw.githubusercontent.com/phistrom/routeros-mkdir/master/persist_create_mkdir_function.rsc" \
    as-value output=user];
    :local script [:parse ($result->"data")]
    $script;
}

```

# Usage
On the command line, you can simply type `$mkdir any/path/you/want`, and the entire folder tree will be created if necessary. If the path already exists, the function quits without doing anything.

In a script, you must have a `:global mkdir;` declaration at the top of your script in order to use `$mkdir`.

### Example
```
:global mkdir;
# ensure backups directory exists
$mkdir "disk1/backups";
/system backup save name=disk1/backups/backup;
```

# How it Works
It uses the `/tool fetch` command as [demonstrated here on the Mikrotik official Wiki](https://wiki.mikrotik.com/wiki/Script_to_create_directory) to download a temporary file to the specified folder and then deletes the temporary file.

Besides wrapping the above script in a function variable for easier usage, a lot of extra edge cases are detected and worked around. This script should still work even if you have disabled the FTP service, have a custom FTP service port, have locked your FTP service to certain addresses, or have firewall/NAT rules affecting the FTP port.

# Important Firewall Notice
This script creates temporary firewall rules. They are extremely narrow in scope, should not have any impact on your router's security, and exist only for the two seconds or so that the function is executing. These rules require the 

A `:do {} on-error={}` block is used to ensure that rule cleanup occurs and that all settings are restored to their previous values even if an error occurs creating the new folder.

# Performance
On an RB4011, this function executes in 1 to 2 seconds. After doing extensive `:time` tests, the 2 slowest parts of the code are
  - creation of the temporary file (roughly from 0.004 to 1.004 seconds)
  - `/tool fetch` (roughly 1 second)

The code that creates firewall rules, the temporary user, and changes FTP service settings appear to have a negligible effect on the speed of the function.

This function runs synchronously meaning it does not return until the folder is created (or an error occurs).

# Testing
Only tested on RouterOS **6.44** and **6.45**. Please open an issue on GitHub if you find this does not work with your particular device/OS.

# License
MIT
