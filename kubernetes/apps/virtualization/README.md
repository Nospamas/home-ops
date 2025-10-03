# Virtualized Dev Machine

### Pre-setup assumptions:

- A PVC called `ubuntu-dev` will be provided. In my configs this is provided by a volsync based
component import, using longhorn as the PVC provider. If live migration is desired a CSI capable of
creating `ReadWriteMany` PVC must be used.
- Check the Loadbalancer IP address in the service matches desired IP ranges
- Update SSH & password credentials in the secrets provided


### Initial Setup

Configs in here are set up to run an Ubuntu 24.04.03 Deskop dev VM. General process / useful commands
for install:

`kubectl get all -n virtualization`
`kubectl get all -n pvc`

Check the resources as they're created by flux in cluster. It takes a few minutes before the VM is ready
as it installs the kubevirt components, creates and backs up the initial PVC, downloads the ubuntu ISO and
finally starts booting the machine. Pay particular  attention to the ubutu-24-04-desktop datavolume that will
download and mount the install ISO automatically.

PVCs may be in a waiting/unbound state while things spin up, keep an eye out for errors on the `virtualmachine` or
`virtualmachineinstance` objects, but expect some errors before the datavolume `Importing` process is completed.

### Post initialization

Virtctl is needed for these next few steps, installation instructions are available on the
[kubevirt site](https://kubevirt.io/user-guide/user_workloads/virtctl_client_tool/). I'm using it through the
`krew` plugin and will use commands that reflect that.

### Connecting and installing

In order to do the ubuntu installation you can set up a VNC proxy, or connect directly.

`kubectl virt vnc ubuntu-dev --proxy-only -n virtualization`

If using the proxy only, you can connect to the vnc server on your local machine at the port noted by the command.
Once connected you can follow the visual installer as usual. In my instance the volsynced 50gb PVC `ubuntu-dev`
was my installation target and was mounted as /sdb.

Once installed I enabled SSH and gnome-remote-desktop for external access. A kubernetes LoadBalancer service that
allows access to these ports has been set up with the default IP `192.168.2.204`.

## Other useful command lines

`kubectl virt <command> ubuntu-dev -n virtualization` - where `<command>` is one of `start`, `stop` and `restart`
issues start stop and restart commands to the VM. Should gracefully shutdown where possible. Useful for updating
VM definitions as these won't apply to a running instance.

## QEMU guest agent

For ubuntu the guest agent can be installed via `apt install qemu-guest-agent` and should be available on the next
restart. `kubectl virt guestosinfo ubuntu-dev -n virtualization` will provide VM information if it has been
installed correctly. Once installed, the VM will sync credentials from the kubernetes secret `ubuntu-dev-credentials`

## Troubleshooting

### Data importer restarting

This seems to happen if you provide a datavolume with insufficient space for the downloaded ISO. Increase the
PV size.

## TODO:

- Can I work out how to thin provision the ubuntu drive or use it directly (maybe ditch LVM?) so that it doesn't always cost 50gb to back up?