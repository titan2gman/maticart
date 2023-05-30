# README

# Development server

## Basic description of the project

matic.art is a website that trades NFTs.

It uses mysql, elasticsearch and redis. The website itself is coded with the RoR framework, but it heavily uses javascript for dApp integration (web3.js)
It is served through an apache2/passenger combination

- ruby version 2.6.0 is managed via rbenv installed in /home/matic
- node version 15.12.0 is managed via nvm installed in /home/matic

## local installation

### setup to interact with polygon mainnet

In order to mint tokens, your installation should be able to sign the mint operations with a specific private key.
The correct key `signer_private_key` should be written in the credentials.yml.enc database.

```console
$ EDITOR=vim rails credentials:edit
```


## Connecting to a prepared server

A development server is installed with all the packages needed to run matic.art and the server can be seen on a public ip.

You will need a private key to ssh into the server as user `ubuntu`
If you have not done so already, you will also need to add a public/private key pair to your github account in order to work with the repository.

Considering you are using `putty` to ssh into the server, you should probably use an ssh-agent like `pageant` to manage your keys and add 2 keys :
 - the matic ssh key given to you to connect to the server
 - your github developer ssh key if you want to interact with the maticart repository


```console
# connecting to the server + forwarding Agent keys
$ ssh -A ubuntu@server
```

The development takes place under a user called "matic". If you want to interact with the git checkout that is available, you need to forward your github key to the user.

A typical session will involve the following commands (the first 3 are necessary to forward the ssh key to the `matic` user

```console
ubuntu$ setfacl -m matic:x   $(dirname "$SSH_AUTH_SOCK")
ubuntu$ setfacl -m matic:rwx "$SSH_AUTH_SOCK"
ubuntu$ sudo --preserve-env=SSH_AUTH_SOCK -i -u matic
ubuntu$ cd /var/www/html/rarible
```

you can then interact with the code and restart the server by calling

```console
matic$ restartNft
```

All work on a project should be done in a dedicated branch to avoid messing with the `master` branch.

# Production

## Sidekiq

Sidekiq is used by ruby for background process queues. It is installed as a systemd service. There is a specific administration panel on https://matic.art/sidekiq

Detailed logs can be seen on the server with the command

```console
ubuntu$ journalctl -u sidekiq -f 
```



