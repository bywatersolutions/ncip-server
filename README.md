# NCIP Server for Koha

## Security

This NCIP server can support token based authentication.
To enable token based authentication:
* Create a Koha system preference named `NcipRequireToken`, set it to 1 to enforce tokens
* Create a Koha system preference named `NcipToken` with a token you've generated
* Pass the token in the API endpoint you've set up for your NCIP server, e.g. if it was `my.ils.lib/ncip`, it will now be `my.ils.ib/ncip/TokenGoesHere`.

## Installation

### For package sites, become the instance user

```bash
sudo koha-shell <instance>
```

### Clone the git repository for the NCIP server

```bash
git clone https://github.com/bywatersolutions/ncip-server.git
```

### Become your own user again

```bash
exit
```

### Install dependancies

Install cpanminus:
```bash
curl -L https://cpanmin.us | sudo perl - App::cpanminus
```

Install the ncip-server dependancies using cpanm
```bash
sudo cpanm --installdeps .
```

### For package sites, become the instance user

```bash
sudo koha-shell <instance>
```

### Set up config.yml

Copy the config.yml.example file to config.yml

```bash
cd ncip-server
cp config.yml.example config.yml
```

Edit the `views: "/path/to/ncip-server/templates/"` line to point to the actual path you have the ncip-server template directory at. For whatever reason, this must be an absolute path and must be configured on a per-installation basis.

### Become your own user again

```bash
exit
```

### Set up the Init script

Copy the `init-script-template` file to your init directory. For Debian, you would copy it to init.d:
```bash
sudo cp init-script-template /etc/init.d/ncip-server
```

Edit the file you just created:
* Update the line `export KOHA_CONF="/path/to/koha-conf.xml"` to point to your production `koha-conf.xml` file. 
* Update the line `HOME_DIR="/home/koha"` to point to the Koha home directory. For Koha package installtions, that would be /var/lib/koha/<instancename> . For git installs it will be the home directory of the user that contains the Koha git clone.
* Update various other path definitions as necessary
* You may also change the port to a different port if 3001 is already being used on your server.

Configure the init script to run at boot
```bash
sudo update-rc.d ncip-server defaults
```
### Expose the ncip-server to the outside world

Modify you Koha Apache configuration, in the Intranet section, add the following:
```apache
ProxyPass /ncip http://127.0.0.1:3000 retry=0
ProxyPassReverse /ncip  http://127.0.0.1:3000 retry=0
```

### Enable ModProxy for apache
```bash
LoadModule proxy_module /usr/lib/apache2/modules/mod_proxy.so
LoadModule proxy_http_module /usr/lib/apache2/modules/mod_proxy_http.so
ProxyPass /ncip http://127.0.0.1:3000 retry=0
ProxyPassReverse /ncip  http://127.0.0.1:3000 retry=0
```

### Start the server!
```bash
sudo /etc/init.d/ncip-server start
```


## Installation via Docker

### Run using image from Docker Hub
```bash
docker run -d --net="host" --restart=always --mount type=bind,source=/usr/share/koha/lib/,target=/kohalib --mount type=bind,source=/etc/koha/sites/<instance>/koha-conf.xml,target=/koha-conf.xml --mount type=bind,source=/var/lib/koha/<instance>/ncip-config.yml,target=/app/config.yml --name koha-ncip bywater/koha-ncip-server:latest
```

*OR*

### Clone the NCIP server git repo

```bash
git clone https://github.com/bywatersolutions/ncip-server.git
```

### Build the docker image

```bash
docker build -t ncip -f docker/Dockerfile .
```

### Make a copy of the config file and edit it

```bash
cp docker/files/config.yml.template /var/lib/koha/<instance>/ncip-config.yml
```

### Start the container
```bash
docker run -d --net="host" --restart=always --mount type=bind,source=/usr/share/koha/lib/,target=/kohalib --mount type=bind,source=/etc/koha/sites/<instance>/koha-conf.xml,target=/koha-conf.xml --mount type=bind,source=/var/lib/koha/<instance>/ncip-config.yml,target=/app/config.yml --name koha-ncip ncip
```

* Bind `/usr/share/koha/lib/,target=/kohalib` or `kohaclone` ( for git installs ) to `kohalib` and the `koha-conf.xml` to `/koha-conf.xml`
* Bind the `config.yml.template` copy to `/app/config.yml`

### Maintenance

#### Restarting the ncip server

If you've followed the directions above, it should be as simple as

```bash
docker restart koha-ncip
```

### Troubleshooting

#### Error: Server response is `Dancer::Response` instead of NCIP XML

The most likely cause of this problem is an incorrect template path in the NCIP server config file. The template path must be an absolute ( not relative ) path pointing to the NCIP server templates directory.
