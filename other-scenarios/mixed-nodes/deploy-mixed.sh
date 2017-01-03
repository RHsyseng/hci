source ~/stackrc
time openstack overcloud deploy --templates \
-r ~/custom-templates/custom-roles-mixed.yaml \
-e /usr/share/openstack-tripleo-heat-templates/environments/puppet-pacemaker.yaml \
-e /usr/share/openstack-tripleo-heat-templates/environments/network-isolation.yaml \
-e /usr/share/openstack-tripleo-heat-templates/environments/storage-environment.yaml \
-e ~/custom-templates/network-mixed.yaml \
-e ~/custom-templates/ceph-mixed.yaml \
-e ~/custom-templates/compute-mixed.yaml \
-e ~/custom-templates/layout-mixed.yaml
