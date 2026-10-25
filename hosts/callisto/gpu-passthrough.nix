# Pass the NVIDIA Quadro P4000 (0000:af:00) through to the Docker VM, as
# Proxmox did with hostpci0. The host's own console uses the onboard
# Matrox G200eW3, so the host never needs the NVIDIA card.
{...}: {
  boot.kernelParams = [
    "intel_iommu=on"
    "iommu=pt"
    # Claim both functions of the card for vfio-pci at boot, before any
    # graphics driver can: 10de:1bb1 (GPU), 10de:10f0 (HDMI audio).
    "vfio-pci.ids=10de:1bb1,10de:10f0"
  ];
  boot.initrd.kernelModules = ["vfio_pci" "vfio" "vfio_iommu_type1"];
  boot.blacklistedKernelModules = ["nouveau" "nvidia" "nvidiafb"];
}
