{
    /system script remove [find name=create_mkdir_function];
    /system script
add dont-require-permissions=no name=create_mkdir_function \
    policy=read,write source="# Written by Phillip Stromberg in 2019\r\
    \n# Distributed under the MIT license\r\
    \n# \r\
    \n# \r\
    \n# this creates a function called \$mkdir\r\
    \n# from the command line you will be able to just type \"\$mkdir some/new\
    /folder\"\r\
    \n# and all the folders that need to be created will be\r\
    \n# if the folder already existed, it is ignored\r\
    \n\r\
    \n:log info \"Creating \\\$mkdir function...\"\r\
    \n\r\
    \n:global mkdir do={\r\
    \n    # \$1 refers to the input variable the user passed in to us\r\
    \n    :local newFolder \$1;\r\
    \n\r\
    \n    # we'll use this variable to report error messages that may arise\r\
    \n    :local errorMsg;\r\
    \n\r\
    \n    # if the user put a slash on the end of the new folder name, remove \
    it\r\
    \n    # i.e. \"some/test/\" becomes \"some/test\"\r\
    \n    :while (([:pick \$newFolder ([:len \$newFolder] - 1)]) = \"/\") do={\
    \r\
    \n        :set newFolder [:pick \$newFolder 0 ([:len \$newFolder] - 1)]\r\
    \n    }\r\
    \n\r\
    \n    # if the user put a slash at the beginning of the new folder name, r\
    emove it\r\
    \n    # i.e. \"/some/test\" becomes \"some/test\"\r\
    \n    :while ([:pick \$newFolder 0] = \"/\") do={\r\
    \n        :set newFolder [:pick \$newFolder 1 [:len \$newFolder]]\r\
    \n    }\r\
    \n\r\
    \n    :if ([/file find name=\$newFolder] != \"\") do={\r\
    \n        :set errorMsg \"'\$newFolder' already exists.\";\r\
    \n        :log debug \"mkdir: \$errorMsg\";\r\
    \n        :return \$newFolder;\r\
    \n    }\r\
    \n\r\
    \n    # the name of the temp file to create\r\
    \n    :local tempfile \"mkdir_temp_file.txt\";\r\
    \n\r\
    \n    # port 0 is unlikely to be open to HTTP requests...\r\
    \n    :local fakeURL \"http://127.0.0.1:0/should-not-exist.txt\";\r\
    \n\r\
    \n    :local fullTempPath (\$newFolder . \"/\" . \$tempfile);\r\
    \n\r\
    \n    # this is where the folder creation happens\r\
    \n    # `as-value` prevents status messages from printing\r\
    \n    # wrapping in a `:do {...} on-error` prevents error messages from pr\
    inting.\r\
    \n    :do {\r\
    \n        /tool fetch dst-path=\"\$fullTempPath\" url=\"\$fakeURL\" durati\
    on=0.001s as-value;\r\
    \n    } on-error={}\r\
    \n\r\
    \n    # this waits for the temporary dir to show up so there isn't a race \
    \r\
    \n    # condition where you call mkdir and then try to do something before\
    \_the \r\
    \n    # folder is actually created\r\
    \n    :local count 0;\r\
    \n    :while ([/file find name=\"\$newFolder\"] = \"\") do={\r\
    \n        :if (\$count >= 50) do={\r\
    \n            # after 50 * 0.1s delays, it's been 5 seconds, which should \
    be long enough\r\
    \n            :set errorMsg \"New folder could not be created at \$newFold\
    er\";\r\
    \n            :log error \"mkdir: \$errorMsg\"\r\
    \n            :error \$errorMsg\r\
    \n        }\r\
    \n        :delay 0.1s;\r\
    \n        :set count (\$count + 1);\r\
    \n    }\r\
    \n\r\
    \n    :return \$newFolder;\r\
    \n}\r\
    \n\r\
    \n:log info \"Created function \\\$mkdir\"\r\
    \n"

    :delay 1s

    /system scheduler remove [find name=create_mkdir_function_on_startup];

    # scheduler requires the "policy" and "test" permissions to make $mkdir a global variable
    # non-admins will have to run the script manually every time as they cannot 
    # view other users' global variables and their own global variables are treated as
    # :local variables.
    /system scheduler
    add name=create_mkdir_function_on_startup on-event="/system script run create_mkdir_function;" policy=read,write,policy,test start-time=startup

    /system script run create_mkdir_function;
}
