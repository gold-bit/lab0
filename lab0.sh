#!/bin/bash

# Script to deploy OpenStack using Packstack on CentOS

# 1. Install Packstack Utility Package
echo "Installing Packstack..."
dnf install -y openstack-packstack

# 2. Deploy OpenStack using Packstack
echo "Creating configuration file..."
cat > ~/packstack-answers.txt << EOF
[general]
CONFIG_SSH_KEY=/root/.ssh/id_rsa.pub
CONFIG_DEFAULT_PASSWORD=password
CONFIG_SERVICE_WORKERS=%{::processorcount}
CONFIG_MARIADB_INSTALL=y
CONFIG_GLANCE_INSTALL=y
CONFIG_CINDER_INSTALL=y
CONFIG_MANILA_INSTALL=n
CONFIG_NOVA_INSTALL=y
CONFIG_NEUTRON_INSTALL=y
CONFIG_HORIZON_INSTALL=y
CONFIG_SWIFT_INSTALL=n
CONFIG_CEILOMETER_INSTALL=y
CONFIG_AODH_INSTALL=y
CONFIG_HEAT_INSTALL=y
CONFIG_TROVE_INSTALL=n
CONFIG_IRONIC_INSTALL=n
CONFIG_CLIENT_INSTALL=y
CONFIG_CONTROLLER_HOST=192.168.100.50
CONFIG_COMPUTE_HOSTS=192.168.100.50,192.168.100.51
CONFIG_NETWORK_HOSTS=192.168.100.50
CONFIG_STORAGE_HOST=192.168.100.50
CONFIG_AMQP_BACKEND=rabbitmq
CONFIG_AMQP_HOST=192.168.100.50
EOF

echo "Reviewing configuration file..."
cat -n ~/packstack-answers.txt

echo "Bootstrapping OpenStack using Packstack..."
packstack --answer-file=~/packstack-answers.txt

# 3. Configuring OpenStack Networking, Security Groups, and Cinder Block Storage
echo "Sourcing keystonerc_admin..."
source ~/keystonerc_admin

echo "Verifying OVS bridge creation..."
ovs-vsctl show
openstack network list

echo "Listing OpenStack agents..."
openstack network agent list

echo "Listing subnets..."
openstack subnet list

echo "Listing routers..."
openstack router list

echo "Listing flavors..."
openstack flavor list

# 3.9 - Creating a new security group "basic"
echo "Creating security group 'basic'..."
openstack security group create basic --description "Allow base ports"

echo "Creating security group rules for basic..."
openstack security group rule create --protocol TCP --dst-port 22 --remote-ip 0.0.0.0/0 basic
openstack security group rule create --protocol TCP --dst-port 80 --remote-ip 0.0.0.0/0 basic
openstack security group rule create --protocol TCP --dst-port 443 --remote-ip 0.0.0.0/0 basic
openstack security group rule create --protocol ICMP --remote-ip 0.0.0.0/0 basic

echo "Listing security groups..."
openstack security group list

# 3.11 - Configure Cinder to use LVM
echo "Configuring Cinder to use LVM..."
crudini --set /etc/cinder/cinder.conf DEFAULT volume_clear none

# 3.12 - Adding a physical hard drive
echo "Creating physical volume..."
pvcreate /dev/sdb

# 3.13 - Checking physical volume status
echo "Checking physical volume status..."
pvdisplay /dev/sdb

# 3.14 - Restarting Cinder services
echo "Restarting Cinder services..."
for service in api scheduler volume; do
    systemctl restart openstack-cinder-$service
done

# 3.15 - Listing volume services
echo "Listing volume services..."
openstack volume service list

# 4. Compute Node Discovery and Instance Launch
echo "Listing nova compute resources..."
openstack compute service list

echo "Listing OpenStack images..."
openstack image list

# 5. Accessing the OpenStack Horizon Dashboard
echo "Commenting out Memcached configuration..."
vim /etc/openstack-dashboard/local_settings

echo "Access OpenStack Horizon dashboard at http://192.168.100.50/dashboard"
echo "Your login credentials are:"
echo "User Name: admin"
echo "Password: password"

# 5.3 - Displaying keystonerc_admin contents
echo "Displaying keystonerc_admin contents..."
cat ~/keystonerc_admin

echo "Deployment complete!"
