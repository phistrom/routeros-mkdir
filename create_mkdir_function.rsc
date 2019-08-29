# Written by Phillip Stromberg in 2019
# Distributed under the MIT license
# 
# 
# this creates a function called $mkdir
# from the command line you will be able to just type "$mkdir some/new/folder"
# and all the folders that need to be created will be
# if the folder already existed, it is ignored

:log info "Creating \$mkdir function..."

:global mkdir do={
    # $1 refers to the input variable the user passed in to us
    :local newFolder $1;

    :if ([/file find name=$newFolder] != "") do={
        # the :error command seems to be the only way to break out of a script
        # without also killing the terminal someone is in
        :log debug "mkdir: '$newFolder' already exists.";
        :error "'$newFolder' already exists.";
    }

    # the name of the temp file to create
    :local tempfile "mkdir_temp_file.txt";

    # the comment that will be put on firewall rules that are created
    :local mkdirRule "mkdir_temp_rule"

    # Get started creating the temp file now because
    # it seems to take about a full second for it
    # to actually appear
    /system clock print file=$tempfile;

    # the name of a temporary user
    :local tempuser "__dircreate";

    # generate as random a password as we can for this temporary user
    :local passwd [:tostr ([/system resource get cpu-load] . [/system identity get name] . [/system resource get free-memory])];

    # was FTP disabled to begin with?
    :local isFTPDisabled [/ip service get ftp disabled];

    # remember what the old FTP access list looked like
    :local oldFTPAddr [/ip service get ftp address];

    # we'll use this variable to report error messages that may arise
    :local errorMsg

    # if the user put a slash on the end of the new folder name, remove it
    # i.e. "some/test/" becomes "some/test"
    :while (([:pick $newFolder ([:len $newFolder] - 1)]) = "/") do={
        :set newFolder [:pick $newFolder 0 ([:len $newFolder] - 1)]
    }

    # if the user put a slash at the beginning of the new folder name, remove it
    # i.e. "/some/test" becomes "some/test"
    :while ([:pick $newFolder 0] = "/") do={
        :set newFolder [:pick $newFolder 1 [:len $newFolder]]
    }


    # delete tempuser user or group if either already exist
    :if ([/user find name=$tempuser] != "") do={
        /user remove $tempuser;
    }
    :if ([/user group find name=$tempuser] != "") do={
        /user group remove $tempuser;
    }

    # create temp group for this temp user
    /user group add name=$tempuser policy=ftp,read,write comment="temporary group for mkdir function";

    # Create user
    # Note: this user is restricted to 127.0.0.1 (no outside logins allowed)
    /user add name=$tempuser group=$tempuser address=127.0.0.1/32 comment="temporary user for mkdir function" password=$passwd disabled=no;

    :local newFTPAllowList
    :if ($isFTPDisabled) do={
        # if the FTP service is currently off,
        # we will make localhost the only address
        # that can access it when it comes up
        :set newFTPAllowList 127.0.0.1
    } else={
        # if it's already enabled:
        :if ($oldFTPAddr = "") do={
            # if there are no IP restrictions and the FTP server is already wide open, we don't have to do anyhting
            :set newFTPAllowList [/ip service get ftp address]
        } else={
            # if there is already an allowed list of IPs, append localhost to list of allowed FTP connections
            :set newFTPAllowList ([/ip service get ftp address],127.0.0.1)
        }
    }

    /ip service set ftp disabled=no address=$newFTPAllowList;

    # wrap the rest of this in ":do" which is basically a "try" and "catch"
    # so we can still rollback all changes we made if an error occurs
    :do {
        # We have to wait for OS to finish making the file we
        # started making near the top if it hasn't already.
        # We spin in place, checking every 0.05 seconds to see if the
        # temp file has been created yet.
        :local count 0;
        :while ([/file find name=$tempfile] = "") do={
            :if ($count >= 100) do={
                # after 100 * 0.05s delays, it's been 5 full seconds
                :set errorMsg "Couldn't create a temp file"
                :error $errorMsg
            }
            :delay 0.05s;
            :set count ($count + 1);
        }
        # make the temporary file completely empty (0 bytes)
        /file set $tempfile contents=""
        
        # log in to localhost using FTP, and "download" our temp file to the new folder path
        :do {
            :local ftpPort [/ip service get ftp port];
            :do { /ip firewall filter add action=accept chain=input comment=$mkdirRule dst-address=127.0.0.1 in-interface-list=!all port=$ftpPort protocol=tcp src-address=127.0.0.1 place-before=0 } on-error={}
            :do { 
                /ip firewall mangle
                add action=accept chain=prerouting comment=$mkdirRule dst-address=127.0.0.1 in-interface-list=!all port=$ftpPort protocol=tcp src-address=127.0.0.1 place-before=0
                add action=fasttrack-connection chain=prerouting comment=$mkdirRule dst-address=127.0.0.1 in-interface-list=!all port=$ftpPort protocol=tcp src-address=127.0.0.1 place-before=0
            } on-error={}
            :do { /ip firewall nat add action=accept chain=srcnat comment=$mkdirRule dst-address=127.0.0.1 out-interface-list=!all port=$ftpPort protocol=tcp src-address=127.0.0.1 place-before=0 } on-error={}
            :do { /ip firewall raw add action=accept chain=prerouting comment=$mkdirRule dst-address=127.0.0.1 in-interface-list=!all port=$ftpPort protocol=tcp src-address=127.0.0.1 place-before=0 } on-error={}
            /tool fetch address=127.0.0.1 port=$ftpPort mode=ftp user=$tempuser password=$passwd src-path=$tempfile dst-path="$newFolder/$tempfile";
        } on-error={
            :set errorMsg "Failed to create folder $newFolder";
            :error $errorMsg;
        }

    } on-error={
        :log error "mkdir: $errorMsg";
        :put $errorMsg
    }

    # Clean up

    # put FTP service back exactly like we found it
    :do { /ip service set ftp disabled=$isFTPDisabled address=$oldFTPAddr; } on-error={}
    :do { /user remove $tempuser; } on-error={}
    :do { /user group remove $tempuser; } on-error={}
    :do { /file remove $tempfile; } on-error={}

    # this waits for the fetched temporary file to show up
    # so that we can delete it
    :local count 0;
    :while ([/file find name="$newFolder/$tempfile"] = "") do={
        :if ($count >= 20) do={
            # after 20 * 0.1s delays, it's been 2 seconds, which should be long enough
            :set errorMsg "Couldn't delete $newFolder/$tempFile"
            :log error "mkdir: $errorMsg"
            :error $errorMsg
        }
        :delay 0.1s;
        :set count ($count + 1);
    }

    # remove the firewall rules we created
    :do { /file remove "$newFolder/$tempfile"; } on-error={}
    :do { /ip firewall filter remove [find comment=$mkdirRule] } on-error={}
    :do { /ip firewall mangle remove [find comment=$mkdirRule] } on-error={}
    :do { /ip firewall nat remove [find comment=$mkdirRule] } on-error={}
    :do { /ip firewall raw remove [find comment=$mkdirRule] } on-error={}
}

:log info "Created function \$mkdir"
