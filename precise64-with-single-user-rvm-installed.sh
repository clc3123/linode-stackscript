#!/bin/bash

# <udf name="hostname" label="Hostname" default="home" />
# HOSTNAME=home
# <udf name="fqdn" label="FQDN" default="home.example.com" />
# FQDN=home.chenlichao.com
# <udf name="ip_address" label="IP Address" default="1.2.3.4" />
# IP_ADDRESS="1.2.3.4"
# <udf name="time_zone" label="Time Zone" default="Etc/UTC" />
# TIME_ZONE="Asia/Shanghai"

# <udf name="user_ssh_port" label="Default User SSH Port" default="22" />
# SSH_USER_PORT=22
# <udf name="user_name" label="Default User Name" default="username" />
# USER_NAME=username
# <udf name="user_password" label="Default User Password" default="username" />
# USER_PASSWORD=username
# <udf name="user_pub_key" label="Default User Authorized Pub Key" default="ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCZ5a4st/5p+JH7uxU7h84aedrq9rciqQIWk8RF5Gd835MlvP/eL60mQUbEZ9DbQuTRbHTvNT/HKcZ1GvRfvs7MuEiZcDCaw9qTjoV2Max4eeya4v9n/BBTsQw7gznP7yFa82+5DcH9W+OR/75J1JdzLWz4bw+Rgb/4lym5i6j98x6i6dTOXnCc4uc0t2vrIhqSpxH6cmAoKJtEKKAUQpS8/gGtxVgoOqLTP6jw4HXy+Bi+XTu0C78jSjf6I60fGYd9G4p5ci2iQg7bjnrSGu+2yWHnv35afdNaj8nEp50Ocl4hiMtP9/mcVuN5ffcaxU2hGoKJJodENvyuwaRNRTlX username@gmail.com" />
# USER_PUB_KEY="ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCZ5a4st/5p+JH7uxU7h84aedrq9rciqQIWk8RF5Gd835MlvP/eL60mQUbEZ9DbQuTRbHTvNT/HKcZ1GvRfvs7MuEiZcDCaw9qTjoV2Max4eeya4v9n/BBTsQw7gznP7yFa82+5DcH9W+OR/75J1JdzLWz4bw+Rgb/4lym5i6j98x6i6dTOXnCc4uc0t2vrIhqSpxH6cmAoKJtEKKAUQpS8/gGtxVgoOqLTP6jw4HXy+Bi+XTu0C78jSjf6I60fGYd9G4p5ci2iQg7bjnrSGu+2yWHnv35afdNaj8nEp50Ocl4hiMtP9/mcVuN5ffcaxU2hGoKJJodENvyuwaRNRTlX username@gmail.com"

# <udf name="rvm_version" label="RVM Specific Version" default="stable" />
# RVM_VERSION="1.25.15"
# <udf name="rvm_ruby_version" label="Ruby Specific Version" default="2.0.0" />
# RVM_RUBY_VERSION="1.9.3"

show_msg()
{
  echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
  echo "Start $1"
  echo "<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<"
}

show_msg "modifying hostname & hosts"
echo $HOSTNAME > /etc/hostname
echo "$IP_ADDRESS $FQDN $HOSTNAME" >> /etc/hosts
hostname -F /etc/hostname

show_msg "apt update & upgrade"
cat <<EOF > /etc/apt/sources.list
deb http://us.archive.ubuntu.com/ubuntu/ precise main restricted universe multiverse
deb http://us.archive.ubuntu.com/ubuntu/ precise-updates main restricted universe multiverse
deb http://security.ubuntu.com/ubuntu precise-security main restricted universe multiverse
deb-src http://us.archive.ubuntu.com/ubuntu/ precise main restricted universe multiverse
deb-src http://us.archive.ubuntu.com/ubuntu/ precise-updates main restricted universe multiverse
deb-src http://security.ubuntu.com/ubuntu precise-security main restricted universe multiverse
EOF
apt-get update
apt-get -y upgrade

show_msg "installing common packages"
apt-get -y install build-essential htop byobu vim-nox tree git curl wget

show_msg "modifying time zone"
echo $TIME_ZONE > /etc/timezone
dpkg-reconfigure -f noninteractive tzdata

show_msg "adding admin user"
useradd -U -d /home/$USER_NAME -m -s /bin/bash $USER_NAME
echo "$USER_NAME:$USER_PASSWORD" | chpasswd
cat <<EOF >/tmp/$USER_NAME
$USER_NAME ALL=(ALL) NOPASSWD:ALL
EOF
mv /tmp/$USER_NAME /etc/sudoers.d/$USER_NAME
chmod 0440 /etc/sudoers.d/$USER_NAME

show_msg "installing multi-user rvm version: $RVM_VERSION"
su -l $USER_NAME <<EOF
if [[ $RVM_VERSION == "stable" ]]
then
  curl -sSL https://get.rvm.io | sudo bash -s -- stable --without-gems="rvm rubygems-bundler"
else
  curl -sSL https://get.rvm.io | sudo bash -s -- --version $RVM_VERSION --without-gems="rvm rubygems-bundler"
fi
EOF

show_msg "installing ruby version: $RVM_RUBY_VERSION"
source /etc/profile.d/rvm.sh
rvm requirements
rvm install $RVM_RUBY_VERSION
usermod -a -G rvm $USER_NAME

show_msg "authorizing admin user pub key"
USER_SSH_DIR=/home/$USER_NAME/.ssh
mkdir -m 0700 $USER_SSH_DIR
echo $USER_PUB_KEY > $USER_SSH_DIR/authorized_keys
chmod 0600 $USER_SSH_DIR/authorized_keys
chown -R $USER_NAME:$USER_NAME $USER_SSH_DIR
 
show_msg "turning on colored shell prompt"
sed -i '/^#force_color_prompt=yes$/a\
force_color_prompt=yes' /home/$USER_NAME/.bashrc
chown $USER_NAME:$USER_NAME /home/$USER_NAME/.bashrc

show_msg "adding add_app_runner.sh"
cat <<'EOF' > /home/$USER_NAME/add_app_runner.sh 
#!/bin/bash

if [[ `id -u` -eq 0 && "$#" -eq 1 ]]; then
  APP_RUNNER="$1"
else
  echo "Usage: $ sudo $0 app_runner_name" >&2
  exit 1
fi
useradd -U -d /home/$APP_RUNNER -m -s /bin/bash $APP_RUNNER
EOF
chmod 0700 /home/$USER_NAME/add_app_runner.sh
chown $USER_NAME:$USER_NAME /home/$USER_NAME/add_app_runner.sh

show_msg "modifying sshd setting"
sed -i "s/^Port 22$/Port $USER_SSH_PORT/" /etc/ssh/sshd_config
sed -i 's/^LoginGraceTime 120$/LoginGraceTime 30/' /etc/ssh/sshd_config
sed -i 's/^PermitRootLogin yes$/PermitRootLogin no/' /etc/ssh/sshd_config

show_msg "rebooting now"
reboot
