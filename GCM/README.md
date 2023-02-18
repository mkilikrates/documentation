# Using Git Credential Manager

It will create a local vault using pgp and pass to keep your credentials and avoid ask password every time.

## Download latest Git Credential Manager (GCM)

[Check for the latest Release](https://github.com/GitCredentialManager/git-credential-manager/releases)

Run the following command

```bash
export gitcredversion=$(curl -Ls -o /dev/null -w %{url_effective} https://github.com/GitCredentialManager/git-credential-manager/releases/latest | awk -F "/" '{print $NF}' | cut -c2-)
curl -L -o gcm-linux_amd64.deb https://github.com/GitCredentialManager/git-credential-manager/releases/download/v$gitcredversion/gcm-linux_amd64.$gitcredversion.deb
```
## install Git Credential Manager (GCM)


Run the following command

```bash
sudo dpkg -i gcm-linux_amd64.deb
```

## Install gpg

```bash
sudo apt-get install gnupg
```

Add this variable to your environment as default

```bash
echo "export GPG_TTY=\$(tty)" >> ~/.bashrc
```

Reload your environment variables

```bash
source ~/.bashrc
```

## Install docker-credential-pass

```bash
curl -L -o docker-credential-pass https://github.com/docker/docker-credential-helpers/releases/download/$dockercredversion/docker-credential-pass-$dockercredversion.linux-amd64
chmod +x docker-credential-pass
sudo mv docker-credential-pass /usr/local/bin/
sudo chown root:root /usr/local/bin/docker-credential-pass
sed -i '0,/{/s/{/{\n\t"credsStore": "pass",/' ~/.docker/config.json
```

## Initialize / generate a key

```bash
gpg --full-generate-key
```

[Kind of Key Selection](images/gpgInitialKindKey.JPG)

Select '1' => RSA and RSA (default)

[Key Size](images/gpgInitialKeySize.JPG)

Type '4096' as key size

[expiration](images/gpgInitialExpiration.JPG)

Define the expiration, eg.: 1 year or 0 to never expires

It will ask your Real Name, email and your passphrase (2 times)

Then you can confirm

```bash
gpg --list-secret-keys --keyid-format LONG
```
* `Pay attention to line uid` since you will use that info on your password store settings bellow

## Install passwordstore
```
sudo apt-get install -y pass
```

## Initiate your passwordstore
```bash
pass init "My name <myemail@email.com>" # Info from gpg --list-secret-keys above
```
## setup your github to use passwordstore
```
git config --global credential.helper store
git config --global credential.credentialStore gpg
git config --global credential.helper $(whereis git-credential-manager | awk -F\: '{print $2}')
```

## using windows WSL clipboard to avoid show credentials on screen

execute this command to add option to copy password on windows from WSL

```bash
echo "alias cpass='f(){ pass \"\$1\" | clip.exe; unset -f f; }; f'" >>~/.bash_aliases
```

## How to use

### to add credential

* `it will ask for the credential`

```bash
pass insert <path/credential>
```

### to add multiline credential

* `you can add several lines until press CTRL+D`

```bash
pass insert -m <path/credential>
```

### to generate credential

```bash
pass generate <path/credential>
```

### to remove credential

```bash
pass rm <path/credential>
```

### to see credential

```bash
pass <path/credential>
```

### to copy a credential to clipboard

#### Using Linux/Mac

* `it will keep for 45 seconds`

```bash
pass -c <path/credential>
```

#### Using windows/wlc

* `it will keep for 45 seconds`

```bash
cpass <path/credential>
```

## GitHub pass
Use your git as usual, but the first time it will record your credentials for both proxy and github to avoid asking again

[list credentials on passwordstore](images/passCredentialList.JPG)
```
pass
```

## Relevant Links

[Git Credential Manager (GCM)](https://github.com/GitCredentialManager/git-credential-manager) 
[GNU Privacy Guard](https://gnupg.org/)
[Password Store](https://www.passwordstore.org/)