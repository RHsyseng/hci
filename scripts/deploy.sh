source ~/stackrc
time openstack overcloud deploy --templates \
-e /usr/share/openstack-tripleo-heat-templates/environments/puppet-pacemaker.yaml \
-e /usr/share/openstack-tripleo-heat-templates/environments/network-isolation.yaml \
-e /usr/share/openstack-tripleo-heat-templates/environments/storage-environment.yaml \
-e ~/custom-templates/network.yaml \
-e ~/custom-templates/hyperconverged-ceph.yaml \
-e ~/custom-templates/ceph.yaml \
--control-flavor control \
--control-scale 3 \
--compute-flavor compute \
--compute-scale 3 \
--ntp-server 10.5.26.10 
