. /vagrant/common.sh

MY_IP=$(ifconfig eth1 | awk '/inet addr/ {split ($2,A,":"); print A[2]}')
MYSQL_HOST=${CONTROLLER_HOST}

sudo apt-get -y install cinder-api cinder-scheduler cinder-volume open-iscsi python-cinderclient tgt python-mysqldb

CINDER_CONF=/etc/cinder/cinder.conf
CINDER_API_PASTE=/etc/cinder/api-paste.ini

cat > /tmp/cinder.conf << EOF
[DEFAULT]
rootwrap_config = /etc/cinder/rootwrap.conf
sql_connection = mysql://cinder:openstack@${MYSQL_HOST}/cinder
api_paste_confg = /etc/cinder/api-paste.ini

iscsi_helper = tgtadm
volume_name_template = volume-%s
volume_group = cinder-volumes
verbose = True
auth_strategy = keystone
state_path = /var/lib/cinder
lock_path = /var/lock/cinder
volumes_dir = /var/lib/cinder/volumes

# Ubuntu
rabbit_host = ${MYSQL_HOST} 

EOF

  sudo rm -f $CINDER_CONF
  sudo mv /tmp/cinder.conf $CINDER_CONF
  sudo chmod 0640 $CINDER_CONF
  sudo chown cinder:cinder $CINDER_CONF


sudo sed -i 's/127.0.0.1/'${CONTROLLER_HOST}'/g' $CINDER_API_PASTE
sudo sed -i "s/%SERVICE_TENANT_NAME%/service/g" $CINDER_API_PASTE
sudo sed -i "s/%SERVICE_USER%/cinder/g" $CINDER_API_PASTE
sudo sed -i "s/%SERVICE_PASSWORD%/cinder/g" $CINDER_API_PASTE
sudo sed -i "s/%SERVICE_PASSWORD%/cinder/g" $CINDER_API_PASTE
sudo sed -i "s/^signing_dir/#signing_dir/" $CINDER_API_PASTE

sudo sed -i '    s/filter = \[ \"a\/\.\*\/\" \]/filter = [ \"a\/loop\/\"\, \"a\/sdb1\/\", \"r\/\.\*\/\"]/' /etc/lvm/lvm.conf

sudo sh -c "echo 'include $volumes_dir/*' >> /etc/tgt/conf.d/cinder.conf"
sudo sh -c "echo 'include /etc/tgt/conf.d/cinder_tgt.conf
include /etc/tgt/conf.d/cinder.conf
default-driver iscsi' > /etc/tgt/targets.conf"

sudo restart tgt
sudo cinder-manage db sync

cd /home
dd if=/dev/zero of=cinder-volumes bs=1 count=0 seek=2G
sudo losetup /dev/loop2 cinder-volumes
sudo sh -c "echo 'n
p
1


t
8e
w
'|fdisk /dev/loop2"
sudo pvcreate /dev/loop2
sudo vgcreate cinder-volumes /dev/loop2
sudo pvscan

sudo service cinder-volume restart
sudo service cinder-api restart
sudo service cinder-scheduler restart
