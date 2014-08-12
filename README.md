# Ubuntu 12.04.2 LTS + FreeRADIUS + Google Authenticator + SSH Certificate Authority

## 1. Security model

This setup is for the extremely paranoid sysadmin who doesn't trust any single computer,
and wants to protect the servers behind two layers of security, using both
SSH keys _and_ Google Authenticator.

Both SSH keys and Google Authenticator have their security issues, but in combination its
possible to achieve a higher level of security than possible with any single one of them.

We will install Google Authenticator+FreeRADIUS on a separate server,
to avoid the hassle with one Google Authenticator key per server,
instead all servers will verify the credentials against the FreeRADIUS server over the network.

Two physically separate computers are used to protect the entire intrastructure:

1. SSH Certificate Authority:
    - Not connected to the network, stand-alone computer, totally isolated.
    - Responsible for signing users public keys issuing SSH certificates.

2. FreeRADIUS + Google Authenticator:
    - Connect to the network.
    - Holds all users secret Google Authenticator keys.
    - Accept RADIUS authentication requests from all servers over the network.

Traditional PKI models rely on a single CA-server to be kept secure.
If the CA-server is compromised, you are doomed and everything fails.

In this model however, you are only screwed if _both_ your CA-server _and_ your FreeRADIUS server are compromised.

The new <code>AuthenticationMethods</code> option in <code>sshd_config</code> only exists in OpenSSH 6.2p1 and later,
which is not yet available for Ubuntu, so we need to compile it from source.

## 2. Computers in example

In this example, we will install Ubuntu 12.04.2 LTS on three separate servers.
The following IPs and hostnames are used throughout the text:

    ------N/A----- sshca
    192.168.50.132 radius
    192.168.50.133 server

Before proceeding, make sure you update and upgrade first to get the latest packages.

    sudo apt-get -q -y update
    sudo apt-get -q -y upgrade

## 3. SSH Certificate Authority

The SSH CA server has a private and a public key, which are normal SSH keys,
but instead of being used to connect, the private key is used to sign the
users public keys and generate a certificate for each public key.

The servers only need the SSH CA's public key. Any user with a private/public key,
where the public key has been signed by the SSH CA can then connect to any of the
servers in the network trusting the SSH CA.

CAUTION: If the SSH CA would be compromised, it is impossible to know if any keys might
exist in the wild which were signed by the intruder using the SSH CA private key.
This is one of the reasons why it's a good idea to have an extra layer of security.

When a new user is to be granted access to all the servers in the network,
you must request a public key from the user, copy it to the SSH CA, sign it,
and return the generated certificate to the user.

The user copies the certificate to the <code>~/.ssh</code> directory:

    # client:
    ~/.ssh/id_rsa - private key
    ~/.ssh/id_rsa.pub - public key
    ~/.ssh/id_rsa-cert.pub - certificate

In this example, we will store the SSH CA files in <code>/etc/ssh/</code>:

    # sshca:
    /etc/ssh/ca-key - private CA-key
    /etc/ssh/ca-key.pub - public CA-key

To generate the keys on the SSH CA:

    # sshca:
    sudo ssh-keygen -f /etc/ssh/ca-key
    sudo mkdir /etc/ssh/userpubkeys

Copy the user's public key <code>id_rsa.pub</code> to <code>/etc/ssh/userpubkeys/<code> using the username as the filename, e.g. <code>/etc/ssh/userpubkeys/joel.pub<code>.

Sign the user's public key:

    ssh-keygen -s /etc/ssh/ca-key -I joel -n joel /etc/ssh/userpubkeys/joel.pub

Give the generated certificate <code>/etc/ssh/userpubkeys/joel-cert.pub</code> to the user.

## 4. FreeRADIUS server

This server must be kept extremely secure and must not run any other applications than FreeRADIUS.
Each new user must setup a Google Authenticator key, stored only on the FreeRADIUS server.

First we need to install FreeRADIUS and Google Authenticator:

    RADIUS_SECRET=`openssl rand -hex 32`
    echo "This is your FreeRADIUS secret key: $RADIUS_SECRET"
    sudo apt-get -q -y install build-essential libpam0g-dev freeradius git libqrencode3
    sudo perl -s -i -p -e "s/#\tpam/pam/' /etc/freeradius/sites-enabled/default
    echo "DEFAULT Auth-Type := PAM" | sudo tee -a /etc/freeradius/users
    cat | sudo tee -a /etc/freeradius/clients.conf <<CLIENTS
    client 0.0.0.0/0 {
            secret          = $RADIUS_SECRET
            shortname       = wan
    }
    CLIENTS
    cat | sudo tee /etc/pam.d/radiusd <<RADIUSD
    auth requisite pam_google_authenticator.so forward_pass noskewadj
    auth required pam_unix.so use_first_pass
    RADIUSD
    git clone https://code.google.com/p/google-authenticator/
    cd google-authenticator/libpam/
    make
    sudo make install
    sudo service freeradius restart

Then we add the new user, in the example the user is "joel":

    sudo adduser joel
    sudo su -l joel
    google-authenticator
    # Do you want authentication tokens to be time-based (y/n) y
    # Scan the QR-code displayed using the Google Authenticator app
    # Do you want me to update your "/home/test/.google_authenticator" file (y/n) y
    # Do you want to disallow multiple uses of the same authentication...(y/n) y
    # By default, tokens are good for 30 seconds....Do you want to do so (y/n) n
    # If the computer that you are ...Do you want to enable rate-limiting (y/n) y

Test if it works.
Replace "password" with your password and "123456" with the Google Authenticator code.

    radtest joel password123456 localhost 1812 $RADIUS_SECRET

## 5. Configure all the servers

Each server must have the SSH CA's public key installed and be configured to trust it.

Copy <code>/etc/ssh/ca-key.pub</code> from the SSH CA to the same location on each server.

Build OpenSSH 6.2p1 from source.
The <code>./configure</code> options are the same as for the pre-installed version.

    sudo apt-get build-dep openssh-server
    wget https://launchpad.net/openssh/main/6.2p1/+download/openssh-6.2p1.tar.gz
    tar xvzf openssh-6.2p1.tar.gz
    cd openssh-6.2p1
    ./configure --prefix=/usr --with-pam --with-kerberos5=/usr --with-selinux --with-tcp-wrappers --with-libedit --with-4in6 --with-sandbox=rlimit --sysconfdir=/etc/ssh --with-privsep-path=/var/run/sshd --with-mantype=doc --disable-strip --with-consolekit --with-ssl-engine --with-default-path=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/bin/X11:/usr/games --with-superuser-path=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/bin/X11
    make
    sudo make install

Install the PAM module for FreeRADIUS:

    sudo apt-get install libpam-radius-auth

Alter configuration to enforce both SSH key _and_ Google Authenticator.
Replace <code>$RADIUS_SECRET</code> with the 

    sudo perl -s -i -p -e 's/\@include common-auth/auth required pam_radius_auth.so/' /etc/pam.d/sshd
    sudo perl -s -i -p -e 's/ChallengeResponseAuthentication no/#ChallengeResponseAuthentication no/' /etc/ssh/sshd_config
    cat | sudo tee -a /etc/ssh/sshd_config <<SSHD_CONFIG
    UsePAM yes
    PasswordAuthentication no
    ChallengeResponseAuthentication yes
    PubkeyAuthentication yes
    AuthenticationMethods publickey,keyboard-interactive
    TrustedUserCAKeys /etc/ssh/ca-key.pub
    SSHD_CONFIG
    echo "192.168.50.132 $RADIUS_SECRET 3" | sudo tee /etc/pam_radius_auth.conf
    sudo service ssh restart

## 6. Connect from your workstation

    ssh -i ~/.ssh/joel joel@server
    Enter passphrase for key '/Users/joel/.ssh/joel': <enter the passphrase for your SSH-key>
    Authenticated with partial success.
    Password: <enter your user password + Google Authenticator, example: s3cr3t123456>
