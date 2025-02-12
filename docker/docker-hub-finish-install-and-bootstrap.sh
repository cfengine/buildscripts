dpkg --configure cfengine-nova-hub
# to reduce image size, let's lop off share/GUI, it is not technically required and duplicates over 700MB of node_modules in public/scripts
rm -rf /var/cfengine/share/GUI
cf-agent -IB $(hostname -i)
cf-agent -KIf update.cf
cf-agent -KI
cf-agent -KI
cf-agent -KI
# running cfengine3 init script is not needed after bootstrapping, bootstrapping starts all needed services
#/etc/init.d/cfengine3 start
