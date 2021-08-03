#!/usr/bin/expect -f

spawn ssh-add /home/user/.ssh/id_rsa
expect "Enter passphrase for /home/user/.ssh/id_rsa:"
send "passphrase\n";
expect "Identity added: /home/user/.ssh/id_rsa (/home/user/.ssh/id_rsa)"
interact
