# Installing this ShinyApp locally in ubuntu

## Install Shiny Server

Please, follow next instructions, partly inspired on <https://www.rstudio.com/products/shiny/download-server/ubuntu/>:

```bash
sudo apt-get update
sudo apt-get install r-base r-base-dev r-cran-shiny gdebi
wget https://download3.rstudio.org/ubuntu-14.04/x86_64/shiny-server-1.5.16.958-amd64.deb
sudo gdebi shiny-server-1.5.16.958-amd64.deb
```

## Shiny server `user` setup

If you want to have Shiny server running as user `user`, holding the apps in its home directory,
first you have to prepare the directories:

```bash
cd "${HOME}"
mkdir -p SHINY_ROOT SHINY_LOGS
ln -sf /srv/shiny-server/* SHINY_ROOT
```

Then, you have to change file `/etc/shiny-server/shiny-server.conf` as `root` to next content:

```
# Instruct Shiny Server to run applications as the user "user"
run_as user;

# Define a server that listens on port 3838
server {
  listen 3838;

  # Define a location at the base URL
  location / {

    # Host the directory of Shiny Apps stored in this directory
    site_dir /home/user/SHINY_ROOT;

    # Log all Shiny output to files in this directory
    log_dir /home/user/SHINY_LOGS;

    # When a user visits the base URL rather than a particular application,
    # an index of the applications available in this directory will be shown.
    directory_index on;
  }
}
```

and restart the service

```bash
sudo systemctl restart shiny-server
```

## Installing Neurodegenerative Diseases Cancer Comorbidities Shiny app

You have to move to the directory where the Shiny apps live and do next command,
in order to install the app and its dependencies:

```bash
cd "${HOME}"/SHINY_ROOT
git clone https://github.com/bsc-life/neurodegenerative_diseases-cancer_comorbidities.git ndg_cancer_comorbidities
cd ndg_cancer_comorbidities
R -f create_r_user.R
R -f bootstrap.R
```

## Regenerating dependences (**developers only**)

In case the dependencies versions have to be updated, or [regen_bootstrap.R](regen_bootstrap.R) changes,
these are the steps to regenerate the renv profiles:

```bash
cd "${HOME}"/SHINY_ROOT/ndg_cancer_comorbidities
rm -rf renv renv.lock .Rprofile
R -f create_r_user.R
R -f regen_bootstrap.R
R -f bootstrap.R
```

## Apache setup

Be sure Apache2 is installed, and next modules are enabled:

```bash
sudo a2enmod rewrite proxy proxy_http proxy_wstunnel
sudo systemctl restart apache2
```

Add next lines to your virtual host setup file
(`/etc/apache2/sites-enabled/000-default.conf` file or similar),
applying either the generic setup or the specific one.

```apache
	# Generic setup
	RedirectMatch permanent ^/shiny$ /shiny/

        RewriteEngine on
        RewriteCond %{HTTP:Upgrade} =websocket
        RewriteRule /shiny/(.*) ws://localhost:3838/$1 [P,L]
        RewriteCond %{HTTP:Upgrade} !=websocket
        RewriteRule /shiny/(.*) http://localhost:3838/$1 [P,L]
        ProxyPass /shiny/ http://localhost:3838/
        ProxyPassReverse /shiny/ http://localhost:3838/
```

```apache
	# Specific setup
        RedirectMatch permanent ^/ndg_cancer_comorbidities$ /ndg_cancer_comorbidities/

        RewriteCond %{HTTP:Upgrade} =websocket
        RewriteRule /ndg_cancer_comorbidities/(.*) ws://localhost:3838/ndg_cancer_comorbidities/$1 [P,L]
        RewriteCond %{HTTP:Upgrade} !=websocket
        RewriteRule /ndg_cancer_comorbidities/(.*) http://localhost:3838/ndg_cancer_comorbidities/$1 [P,L]
        ProxyPass /ndg_cancer_comorbidities/ http://localhost:3838/ndg_cancer_comorbidities/
        ProxyPassReverse /ndg_cancer_comorbidities/ http://localhost:3838/ndg_cancer_comorbidities/

	ProxyRequests Off
```

And remember to restart the service to enable these changes:

```bash
sudo systemctl restart apache2
```
