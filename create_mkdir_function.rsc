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

    # we'll use this variable to report error messages that may arise
    :local errorMsg;

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

    :if ([/file find name=$newFolder] != "") do={
        :set errorMsg "'$newFolder' already exists.";
        :log debug "mkdir: $errorMsg";
        :return $newFolder;
    }

    # the name of the temp file to create
    :local tempfile "mkdir_temp_file.txt";

    # port 0 is unlikely to be open to HTTP requests...
    :local fakeURL "http://127.0.0.1:0/should-not-exist.txt";

    :local fullTempPath ($newFolder . "/" . $tempfile);

    # this is where the folder creation happens
    # `as-value` prevents status messages from printing
    # wrapping in a `:do {...} on-error` prevents error messages from printing.
    :do {
        /tool fetch dst-path="$fullTempPath" url="$fakeURL" duration=0.001s as-value;
    } on-error={}

    # this waits for the temporary dir to show up so there isn't a race 
    # condition where you call mkdir and then try to do something before the 
    # folder is actually created
    :local count 0;
    :while ([/file find name="$newFolder"] = "") do={
        :if ($count >= 50) do={
            # after 50 * 0.1s delays, it's been 5 seconds, which should be long enough
            :set errorMsg "New folder could not be created at $newFolder";
            :log error "mkdir: $errorMsg"
            :error $errorMsg
        }
        :delay 0.1s;
        :set count ($count + 1);
    }

    :return $newFolder;
}

:log info "Created function \$mkdir"
