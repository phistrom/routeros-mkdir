/system script remove [find name=create_mkdir_function];
/system script
add dont-require-permissions=no name=create_mkdir_function owner=admin \
    policy=ftp,reboot,read,write,policy,test,password,sniff,sensitive,romon \
    source="# Written by Phillip Stromberg in 2019\r\
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
    \n    :if ([/file find name=\$newFolder] != \"\") do={\r\
    \n        # the :error command seems to be the only way to break out of a \
    script\r\
    \n        # without also killing the terminal someone is in\r\
    \n        :log debug \"mkdir: '\$newFolder' already exists.\";\r\
    \n        :error \"'\$newFolder' already exists.\";\r\
    \n    }\r\
    \n\r\
    \n    # the name of the temp file to create\r\
    \n    :local tempfile \"mkdir_temp_file.txt\";\r\
    \n\r\
    \n    # the comment that will be put on firewall rules that are created\r\
    \n    :local mkdirRule \"mkdir_temp_rule\"\r\
    \n\r\
    \n    # Get started creating the temp file now because\r\
    \n    # it seems to take about a full second for it\r\
    \n    # to actually appear\r\
    \n    /system clock print file=\$tempfile;\r\
    \n\r\
    \n    # the name of a temporary user\r\
    \n    :local tempuser \"__dircreate\";\r\
    \n\r\
    \n    # generate as random a password as we can for this temporary user\r\
    \n    :local passwd [:tostr ([/system resource get cpu-load] . [/system id\
    entity get name] . [/system resource get free-memory])];\r\
    \n\r\
    \n    # was FTP disabled to begin with\?\r\
    \n    :local isFTPDisabled [/ip service get ftp disabled];\r\
    \n\r\
    \n    # remember what the old FTP access list looked like\r\
    \n    :local oldFTPAddr [/ip service get ftp address];\r\
    \n\r\
    \n    # we'll use this variable to report error messages that may arise\r\
    \n    :local errorMsg\r\
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
    \n\r\
    \n    # delete tempuser user or group if either already exist\r\
    \n    :if ([/user find name=\$tempuser] != \"\") do={\r\
    \n        /user remove \$tempuser;\r\
    \n    }\r\
    \n    :if ([/user group find name=\$tempuser] != \"\") do={\r\
    \n        /user group remove \$tempuser;\r\
    \n    }\r\
    \n\r\
    \n    # create temp group for this temp user\r\
    \n    /user group add name=\$tempuser policy=ftp,read,write comment=\"temp\
    orary group for mkdir function\";\r\
    \n\r\
    \n    # Create user\r\
    \n    # Note: this user is restricted to 127.0.0.1 (no outside logins allo\
    wed)\r\
    \n    /user add name=\$tempuser group=\$tempuser address=127.0.0.1/32 comm\
    ent=\"temporary user for mkdir function\" password=\$passwd disabled=no;\r\
    \n\r\
    \n    :local newFTPAllowList\r\
    \n    :if (\$isFTPDisabled) do={\r\
    \n        # if the FTP service is currently off,\r\
    \n        # we will make localhost the only address\r\
    \n        # that can access it when it comes up\r\
    \n        :set newFTPAllowList 127.0.0.1\r\
    \n    } else={\r\
    \n        # if it's already enabled:\r\
    \n        :if (\$oldFTPAddr = \"\") do={\r\
    \n            # if there are no IP restrictions and the FTP server is alre\
    ady wide open, we don't have to do anyhting\r\
    \n            :set newFTPAllowList [/ip service get ftp address]\r\
    \n        } else={\r\
    \n            # if there is already an allowed list of IPs, append localho\
    st to list of allowed FTP connections\r\
    \n            :set newFTPAllowList ([/ip service get ftp address],127.0.0.\
    1)\r\
    \n        }\r\
    \n    }\r\
    \n\r\
    \n    /ip service set ftp disabled=no address=\$newFTPAllowList;\r\
    \n\r\
    \n    # wrap the rest of this in \":do\" which is basically a \"try\" and \
    \"catch\"\r\
    \n    # so we can still rollback all changes we made if an error occurs\r\
    \n    :do {\r\
    \n        # We have to wait for OS to finish making the file we\r\
    \n        # started making near the top if it hasn't already.\r\
    \n        # We spin in place, checking every 0.05 seconds to see if the\r\
    \n        # temp file has been created yet.\r\
    \n        :local count 0;\r\
    \n        :while ([/file find name=\$tempfile] = \"\") do={\r\
    \n            :if (\$count >= 100) do={\r\
    \n                # after 100 * 0.05s delays, it's been 5 full seconds\r\
    \n                :set errorMsg \"Couldn't create a temp file\"\r\
    \n                :error \$errorMsg\r\
    \n            }\r\
    \n            :delay 0.05s;\r\
    \n            :set count (\$count + 1);\r\
    \n        }\r\
    \n        # make the temporary file completely empty (0 bytes)\r\
    \n        /file set \$tempfile contents=\"\"\r\
    \n        \r\
    \n        # log in to localhost using FTP, and \"download\" our temp file \
    to the new folder path\r\
    \n        :do {\r\
    \n            :local ftpPort [/ip service get ftp port];\r\
    \n            :do { /ip firewall filter add action=accept chain=input comm\
    ent=\$mkdirRule dst-address=127.0.0.1 in-interface-list=!all port=\$ftpPor\
    t protocol=tcp src-address=127.0.0.1 place-before=0 } on-error={}\r\
    \n            :do { \r\
    \n                /ip firewall mangle\r\
    \n                add action=accept chain=prerouting comment=\$mkdirRule d\
    st-address=127.0.0.1 in-interface-list=!all port=\$ftpPort protocol=tcp sr\
    c-address=127.0.0.1 place-before=0\r\
    \n                add action=fasttrack-connection chain=prerouting comment\
    =\$mkdirRule dst-address=127.0.0.1 in-interface-list=!all port=\$ftpPort p\
    rotocol=tcp src-address=127.0.0.1 place-before=0\r\
    \n            } on-error={}\r\
    \n            :do { /ip firewall nat add action=accept chain=srcnat commen\
    t=\$mkdirRule dst-address=127.0.0.1 out-interface-list=!all port=\$ftpPort\
    \_protocol=tcp src-address=127.0.0.1 place-before=0 } on-error={}\r\
    \n            :do { /ip firewall raw add action=accept chain=prerouting co\
    mment=\$mkdirRule dst-address=127.0.0.1 in-interface-list=!all port=\$ftpP\
    ort protocol=tcp src-address=127.0.0.1 place-before=0 } on-error={}\r\
    \n            /tool fetch address=127.0.0.1 port=\$ftpPort mode=ftp user=\
    \$tempuser password=\$passwd src-path=\$tempfile dst-path=\"\$newFolder/\$\
    tempfile\";\r\
    \n        } on-error={\r\
    \n            :set errorMsg \"Failed to create folder \$newFolder\";\r\
    \n            :error \$errorMsg;\r\
    \n        }\r\
    \n\r\
    \n    } on-error={\r\
    \n        :log error \"mkdir: \$errorMsg\";\r\
    \n        :put \$errorMsg\r\
    \n    }\r\
    \n\r\
    \n    # Clean up\r\
    \n\r\
    \n    # put FTP service back exactly like we found it\r\
    \n    :do { /ip service set ftp disabled=\$isFTPDisabled address=\$oldFTPA\
    ddr; } on-error={}\r\
    \n    :do { /user remove \$tempuser; } on-error={}\r\
    \n    :do { /user group remove \$tempuser; } on-error={}\r\
    \n    :do { /file remove \$tempfile; } on-error={}\r\
    \n\r\
    \n    # this waits for the fetched temporary file to show up\r\
    \n    # so that we can delete it\r\
    \n    :local count 0;\r\
    \n    :while ([/file find name=\"\$newFolder/\$tempfile\"] = \"\") do={\r\
    \n        :if (\$count >= 20) do={\r\
    \n            # after 20 * 0.1s delays, it's been 2 seconds, which should \
    be long enough\r\
    \n            :set errorMsg \"Couldn't delete \$newFolder/\$tempFile\"\r\
    \n            :log error \"mkdir: \$errorMsg\"\r\
    \n            :error \$errorMsg\r\
    \n        }\r\
    \n        :delay 0.1s;\r\
    \n        :set count (\$count + 1);\r\
    \n    }\r\
    \n\r\
    \n    # remove the firewall rules we created\r\
    \n    :do { /file remove \"\$newFolder/\$tempfile\"; } on-error={}\r\
    \n    :do { /ip firewall filter remove [find comment=\$mkdirRule] } on-err\
    or={}\r\
    \n    :do { /ip firewall mangle remove [find comment=\$mkdirRule] } on-err\
    or={}\r\
    \n    :do { /ip firewall nat remove [find comment=\$mkdirRule] } on-error=\
    {}\r\
    \n    :do { /ip firewall raw remove [find comment=\$mkdirRule] } on-error=\
    {}\r\
    \n}\r\
    \n\r\
    \n:log info \"Created function \\\$mkdir\"\r\
    \n"

/system scheduler remove [find name=create_mkdir_function_on_startup];
/system scheduler add name=create_mkdir_function_on_startup on-event=\
    "/system script run create_mkdir_function;" policy=\
    ftp,reboot,read,write,policy,test,password,sniff,sensitive,romon \
    start-time=startup;

/system script run create_mkdir_function;
