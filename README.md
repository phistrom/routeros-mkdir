# mkdir for RouterOS 6 and 7

This is a script that creates a `$mkdir` global variable containing a function. 
After running the script you will be able to create folders on your Mikrotik 
device by simply typing `$mkdir some/new/path`.

  - Easy to use
  - Functionality that was bafflingly left out
  - Should run on Router OS 6.2+ (but only 6.45+ has been tested)

# Installation

## The Easy Way

Copy the `persist_create_mkdir_function.rsc` file to your Mikrotik device and 
then run `/import persist_create_mkdir_function.rsc` This will create the 
function, as well as a new scheduler entry that will create the function on 
startup, ensuring `$mkdir` is always available to you and your scripts.

## The Even Easier Way

Copy and paste the below into your terminal to create the function and persist 
it using a scheduler startup script.
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

On the command line, you can simply type `$mkdir any/path/you/want`, and the 
entire folder tree will be created if necessary. If the path already exists, 
the function quits without doing anything.

In a script, you must have a `:global mkdir;` declaration at the top of your 
script in order to use `$mkdir`.

### Example

```
:global mkdir;
# ensure backups directory exists
$mkdir "disk1/backups";
/system backup save name=disk1/backups/backup;
```

# How it Works

It uses the `/tool fetch` command as 
[demonstrated here on the Mikrotik official Wiki][inspiration] 
to download a temporary file to the specified folder. The folders will be 
created, but the URL given is a non-existent path on localhost so no file is 
created.

This function runs synchronously meaning it does not return until the folder is 
created (or an error occurs).

# Testing
Only tested on RouterOS **6.44**, **6.45**, and **7.2**. Please open an issue on GitHub 
if you find this does not work with your particular device/OS.

# License
MIT

  [inspiration]: <https://web.archive.org/web/20210413040134/https://wiki.mikrotik.com/wiki/Script_to_create_directory>
