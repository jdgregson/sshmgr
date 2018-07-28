# sshmgr
A text-based GUI SSH connection manager for PowerShell.

## About sshmgr
sshmgr is an SSH connection manager for PowerShell. Instead of remembering tens
of SSH usernames, hosts, ports, and identity files, sshmgr will help you keep
them organized and accessible. It works by saving the connection strings in text
files and presenting them in a PowerShell-based GUI. See the screenshots below
for an example.

## Configuration
### Automatic setup
The simplest way to set up sshmgr is just to run it. It will create the default
directory (~/Documents/sshmgr) if it doesn't exist. Once in sshmgr, simply press
'n' to create a new saved connecton. It will prompt you for the name and SSH
string. For example, you might enter "ubuntu@test.local" for the name and
"ssh -p 22 ubuntu@192.168.1.55" for the SSH string. From there you can add,
rename, duplicate, delete, and connect to saved connections as you see fit.

### Manual Configuration
If you want to configure sshmgr manually, you'll need to do the following:
1. decide where you want to save your SSH connection files (the default is
   ~/Documents/sshmgr)
2. edit sshmgr.ps1 and set the $CONNECTION_FOLDER variable to the folder you
   decided onin step 1
3. add some connection files, where the file name is the display name in sshmgr
   (minus ".txt") and the contents are what sshmgr will execute when you connect
   to a saved connection

## Screenshots
![sshmgr in PowerShell 2, Windows 7](https://user-images.githubusercontent.com/3778841/42912741-d434bcfc-8aa5-11e8-82a5-18774aeb7df4.jpg)
![sshmgr in PowerShell 5, Windows 10](https://user-images.githubusercontent.com/3778841/42912742-d44b5778-8aa5-11e8-9163-46831bc24080.jpg)

## PowerShell Support
sshmgr is developed in PowerShell 5, but it is tested for compatibility with:
- PowerShell 5
- PowerShell 4
- PowerShell 2

## Contributing
You're more than welcome to contribute to sshmgr. Feel free to send a pull
request if you've added some useful features. If you need any help, you can
open an issue on the [issue tracker](https://github.com/jdgregson/sshmgr/issues),
or contact me at jdgregson at gmail.

I am particularly interested in hearing the details of any PowerShell errors
that you encounter. Because like, my error popup looks pretty neat, so we should
put all of the errors in there.
