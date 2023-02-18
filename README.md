### Info

#### en:
This Powershell Script creates a linux distribution inside WSL. It also supports vpnkit which can optionally be loaded to have communication from the wsl to windows vpn clients like cisco anyconnect.

The distribution will be provisioned via ansible which can be seperately configured

#### de:
Dieses script erzeugt via wsl eine lauffähige linux infrastruktur die optional auch mit vpn cisco anyconnect kommunizieren kann.

Dabei kann einerseits das vpnkit nachgeladen als auch eine lokale distribution mittels ansible provisioniert werden.

Dazu einfach das ansbile playbook nach den eigenen wünschen befüllen und das script starten

### prerequisites

tested only with windows 10

- wsl 2
- installed windows VM-Platform feature https://aka.ms/wsl2-install


### install

- adjust ansible playbook in the playbook folder
- script uses `Ubuntu-22.04` can be changed in the parameters on the top inside `wsl.ps1`
- run `PowerShell.exe -ExecutionPolicy Bypass -File .\wsl.ps1`
- pick `[1]` or `[2]` depending if you want to install vpnkit
- fresh linux install requires to rerun the script after ubuntu install

## problems

- filesystem error on ubuntu install
	- https://github.com/Microsoft/WSL/issues/3437
	- firewall blocks microsoft store traffic to network