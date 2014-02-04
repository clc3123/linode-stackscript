#!/bin/bash

# <udf name="hostname" label="Hostname" default="username" />
# <udf name="fqdn" label="FQDN" default="username@example.com" />
# <udf name="ip_address" label="IP Address" default="1.2.3.4" />
# <udf name="time_zone" label="Time Zone" default="Etc/UTC" />

# <udf name="user_name" label="Default User Name" default="username" />
# <udf name="user_password" label="Default User Password" default="username" />
# <udf name="user_pub_key" label="Default User Authorized Pub Key" default="ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCZ5a4st/5p+JH7uxU7h84aedrq9rciqQIWk8RF5Gd835MlvP/eL60mQUbEZ9DbQuTRbHTvNT/HKcZ1GvRfvs7MuEiZcDCaw9qTjoV2Max4eeya4v9n/BBTsQw7gznP7yFa82+5DcH9W+OR/75J1JdzLWz4bw+Rgb/4lym5i6j98x6i6dTOXnCc4uc0t2vrIhqSpxH6cmAoKJtEKKAUQpS8/gGtxVgoOqLTP6jw4HXy+Bi+XTu0C78jSjf6I60fGYd9G4p5ci2iQg7bjnrSGu+2yWHnv35afdNaj8nEp50Ocl4hiMtP9/mcVuN5ffcaxU2hGoKJJodENvyuwaRNRTlX username@example.com" />

# <udf name="rvm_version" label="RVM Specific Version" default="stable" />
# <udf name="ruby_version" label="Ruby Specific Version" default="2.0.0" />

echo $HOSTNAME > /etc/hostname
echo "$IP_ADDRESS $FQDN $HOSTNAME" >> /etc/hosts
hostname -F /etc/hostname

cat <<EOF > /etc/apt/sources.list
deb http://us.archive.ubuntu.com/ubuntu/ precise main restricted universe multiverse
deb http://us.archive.ubuntu.com/ubuntu/ precise-updates main restricted universe multiverse
deb http://security.ubuntu.com/ubuntu precise-security main restricted universe multiverse
deb-src http://us.archive.ubuntu.com/ubuntu/ precise main restricted universe multiverse
deb-src http://us.archive.ubuntu.com/ubuntu/ precise-updates main restricted universe multiverse
deb-src http://security.ubuntu.com/ubuntu precise-security main restricted universe multiverse
EOF

apt-get update
apt-get upgrade
apt-get install build-essential htop byobu vim-nox tree git curl wget

echo $TIME_ZONE > /etc/timezone
dpkg-reconfigure -f noninteractive tzdata

useradd -U -d /home/$USER_NAME -m -s /bin/bash $USER_NAME
echo "$USER_NAME:$USER_PASSWORD" | chpasswd
cat <<EOF >/tmp/$USER_NAME
$USER_NAME ALL=(ALL) NOPASSWD:ALL
EOF
mv /tmp/$USER_NAME /etc/sudoers.d/$USER_NAME
chmod 0440 /etc/sudoers.d/$USER_NAME

su -l $USER_NAME <<EOF
if [[ $RVM_VERSION == "stable" ]]
then
  curl -sSL https://get.rvm.io | bash -s -- stable --without-gems="rvm rubygems-bundler"
else
  curl -sSL https://get.rvm.io | bash -s -- --version $RVM_VERSION --without-gems="rvm rubygems-bundler"
fi
source /home/$USER_NAME/.rvm/scripts/rvm
rvm requirements
rvm install $RUBY_VERSION
EOF

USER_SSH_DIR=/home/$USER_NAME/.ssh
mkdir -m 0700 $USER_SSH_DIR
echo $USER_PUB_KEY > $USER_SSH_DIR/authorized_keys
chmod 0600 $USER_SSH_DIR/authorized_keys
chown -R $USER_NAME:$USER_NAME $USER_SSH_DIR
 
sed -i 's/^Port 22$/Port 8888/' /etc/ssh/sshd_config
sed -i 's/^LoginGraceTime 120$/LoginGraceTime 30/' /etc/ssh/sshd_config
sed -i 's/^PermitRootLogin yes$/PermitRootLogin no/' /etc/ssh/sshd_config
service ssh restart
