# freeradius-google-auth

Ubuntu 12.04.2 LTS + FreeRADIUS + Google Authenticator

## 1. Installation

    sudo ./install.sh

## 2. Add user

    sudo adduser test

    sudo su test

    cd ~

    google-authenticator

    # Do you want authentication tokens to be time-based (y/n) y

    # Do you want me to update your "/home/test/.google_authenticator" file (y/n) y

    # Do you want to disallow multiple uses of the same authentication
    # token? This restricts you to one login about every 30s, but it increases
    # your chances to notice or even prevent man-in-the-middle attacks (y/n) y

    # By default, tokens are good for 30 seconds and in order to compensate for
    # possible time-skew between the client and the server, we allow an extra
    # token before and after the current time. If you experience problems with poor
    # time synchronization, you can increase the window from its default
    # size of 1:30min to about 4min. Do you want to do so (y/n) n

    # If the computer that you are logging into isn't hardened against brute-force
    # login attempts, you can enable rate-limiting for the authentication module.
    # By default, this limits attackers to no more than 3 login attempts every 30s.
    # Do you want to enable rate-limiting (y/n) y

    # Scan once you get your custom QR Code, scan it in to your Google Authenticator App.

## 2. Test

radtest test test123696720 localhost 18120 testing123

## 3. Credits

[Jeremy Cox](http://www.supertechguy.com/help/security/freeradius-google-auth)

