# avoid promt blocking after debug messages
$DebugPreference = 'Continue'
#initial ps output encoding
$console = ([console]::OutputEncoding)

#switch to wsl / linux encoding
[console]::OutputEncoding = New-Object System.Text.UnicodeEncoding

#helper
function Finish($code){
    #reset to initial console encoding
    [console]::OutputEncoding = $console
    Write-Debug "finished $($code)"
    Exit $code
}

function CheckWsl(){
    $wslversion = wsl --status | Select-String -Pattern ".*Standardversion: 1.*" -Quiet
    Write-Debug "wsl version 1? $($wslversion -eq $True)"
    if($wslversion -eq $True){
        Write-Debug "set wsl to version 2"
        wsl '--set-default-version' 2
    }
    return wsl --status | Select-String -Pattern ".*Standardversion: 2.*" -Quiet
}


############
## config ##
############

$wslDistroShort = "Ubuntu"
$wslDistro = "Ubuntu-22.04"
$wslDistroFullName = "Ubuntu 22.04 LTS"

$distroImageName = 'Ubuntu.appx'
$distroUrl = 'https://aka.ms/wslubuntu2204' # https://learn.microsoft.com/en-us/windows/wsl/install-manual#downloading-distributions

#vpn kit
$vpnkitPath = 'https://github.com/sakai135/wsl-vpnkit/releases/download/v0.3.4/'
$vpnKitFilename = 'wsl-vpnkit.tar.gz'
$vpnkitUrl = $vpnkitPath + $vpnKitFilename

#configure the menu with 
function Menu{
    #Clear-Host
    Write-Host "----------------[ install ]----------------"
    Write-Host "[1] full install with vpnkit"
    Write-Host "[2] full install without vpnkit"
    Write-Host "-----------[ selective install ]-----------"
    Write-Host "[3] install vpn-kit"
    Write-Host "[4] setup distro"
    Write-Host "[5] provision distro"
    Write-Host "----------------[ remove ]----------------"
    Write-Host "[6] fix podman after restart"
    Write-Host "[7] remove all (vpnkit and distro)"
    return Read-Host "Select Setup (default 1)"
}

# setup

# vpn kit relatet

function FindDistro($name){
    $found = wsl -l | Select-String -Pattern $name -SimpleMatch -Quiet
    Write-Debug "finding $name :$found"
    return $found
}

function DownloadImage($url, $filename){   
    
    Write-Debug "Check download file existence: $filename"

    $dest = (New-Object -ComObject Shell.Application).NameSpace('shell:Downloads').self.Path + '\' + $filename
    if (Test-Path $dest){
        Write-Debug "$filename file exists"
        return $dest
    }



    $size = (Invoke-WebRequest $url -Method Head).Headers.'Content-Length'
    Write-Debug "Downloading $filename from $url to $dest `nfilesize $size"
    Invoke-WebRequest -Uri $url -OutFile $dest -Resume #-UseBasicParsing

    return $dest
}

function InstallVpnkit{
    if(FindDistro('wsl-vpnkit')){
        Write-Debug "vpnkit already installed"
        RemoveVpnKit('wsl-vpnkit')
    }

    $vpnkitlocation = DownloadImage $vpnkitUrl $vpnKitFilename
    Write-Debug "vpnkit located at: $vpnkitlocation"

    #setup
    Write-Debug "install vpnkit"
    $success = wsl --import wsl-vpnkit $env::USERPROFILE\wsl-vpnkit $vpnkitlocation --version 2 | Select-String -Pattern ".*VM-Plattform.*" -Quiet
    if ($success -eq $True){
        Write-Debug "vpn import failed, are VM-Platform components installed and virtualization is active in bios?"
        Finish(1)
    }
    Write-Debug "import success"
    wsl -d wsl-vpnkit

    #start
    Write-Debug "start vpnkit"
    wsl -d wsl-vpnkit service wsl-vpnkit start

    Write-Debug "done"
}

function RemoveVpnKit($distro){
    Write-Debug "removing $distro"
    wsl.exe -d wsl-vpnkit service wsl-vpnkit stop
    wsl -t $distro
    wsl --unregister $distro
}

# linux related

function FindUbuntu{

    $ubuntu = FindDistro('Ubuntu')
    if ($ubuntu){
        $rename = Read-Host "found generic ubuntu, is it $wslDistro ([y]es/[n]o)"

        if ($rename -eq "yes" -or $rename -eq "y"){
            Set-Variable -Name "wslDistro" -Value "Ubuntu" -Scope global
            Write-Debug "working with name $wslDistro"
        }
    }

    return wsl -l | Select-String -Pattern '.* $wslDistro .*' -Quiet
}

function ConfigureDistro{
    Write-Debug "configure distro"
    if (FindUbuntu -ne $True){
        Write-Debug "$wslDistro not installed"
        
        Write-Host "[1] install ubuntu via windows store (fast, requires account)"
        Write-Host "[2] install via commandline (really slow, no account required)"
        Write-Host "[3] provide image manually (download from $distroUrl into $env:USERPROFILE\Downloads and name the file $distroImageName)"

        $setup = Read-Host "select setup (default 3)"
        
        switch ($setup) {
            1 {
                #v1 download via store
                Start-Process "ms-windows-store://pdp/?ProductId=9PN20MSR04DW"
                Write-Debug "restart setup after install of distro is done"
                Finish(1) 
            }
            2 {
                #v2 command download
                Write-Debug "`n
                Downloading distro: $distroImageName, this may take 20 minutes!`n
                You can download it possibly faster via browser INTO YOUR downloads folder`n
                from here: $distroUrl`n
                IMPORTANT name the file $distroImageName"
                $ProgressPreference = 'SilentlyContinue'
                Write-Host "downloading distro, please wait (20mins)"
                $distroDest = DownloadImage $distroUrl $distroImageName
                Write-Host "download finished"

                Write-Debug "distro located at: $distroDest"

                Add-AppxPackage $distroDest
            }
            default {
                $distroDest = (New-Object -ComObject Shell.Application).NameSpace('shell:Downloads').self.Path + '\' + $distroImageName
                if (Test-Path $distroDest){
                    Write-Debug "$distroImageName file exists`n path: $distroDest"
                    Add-AppxPackage $distroDest
                    Start-Process $distroDest
                }
                else {
                    Start-Process "$distroUrl"
                    Finish(1)
                }
            }
        }
    }

    #after install
    #set distro as default
    Write-Debug "set $wslDistro as default"
    wsl --set-default $wslDistro

    Write-Debug "start distro provisioning"
    wsl -e sh ./distro/ubuntu.sh
}

function Provision{

    Write-Debug "Provisioning distro"
    wsl ansible-galaxy collection install containers.podman

    wsl wslpath $PWD.Path.Replace('\','/') '|' xargs -i ansible-playbook '{}/ansible/playbooks/test.yml' -i '{}/ansible/hosts' --connection-local --extra-vars="user-$env:username" --tags "provision"
}

### util

function FixPodman{
    wsl podman stop -a
    wsl podman system prune -f
    wsl rm -rf /tmp/podman-run-'$('id -u')'/libpod/tmp
    wsl wslpath $PWD.Path.Replace('\','/') '|' xargs -i ansible-playbook '{}/ansible/playbooks/test.yml' -i '{}/ansible/hosts' --connection-local --tags "remove"
    Provision

    Write-Debug "if this run showed errors, please repeat"

    Finish(0)
}

function RemoveAll{
    RemoveVpnKit($wslDistro)
    wsl -t $wslDistro
    winget uninstall $wslDistroFullName
    Finish(0)
}


##program start from here

if ($(CheckWsl) -eq $False){
    [console]::OutputEncoding = $console
    Write-Debug "kein deutsches wsl version 2 gefunden"
    Finish(1)
}
else {
    switch (Menu) {
        2 { 
            ConfigureDistro
            Provision
            Finish(0)
         }
        3 { 
            InstallVpnkit
            Finish(0)
        }
        4 { 
            ConfigureDistro
            Finish(0)
        }
        5 { 
            Provision
            Finish(0)
        }
        5 {
            FixPodman
        }
        6 {
            RemoveAll
        }
        Default {
            InstallVpnkit
            ConfigureDistro
            Provision
            Finish(0)
        }
    }
}