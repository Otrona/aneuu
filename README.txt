Aneuu 0 (다시): build the ISO and test it on Xubuntu 26.04
==========================================================

Files
  mkiso                    the build script (runs in an Alpine 3.24 Docker container)
  cjktty-6.18.63.patch.xz  Korean on the kernel console (picked up by mkiso)
  netsurf-fb-hangul.patch  Korean in NetSurf (picked up by mkiso)
  avm                      try the ISO in a QEMU virtual machine
  dk                       start/stop Docker with its data on the SSD
  dasi.epub                the Korean user manual

The build happens inside a throwaway Alpine container, so nothing is
installed on Xubuntu except Docker. Testing happens in QEMU/KVM.


1. Install Docker (once)
-----------------------
  sudo apt update
  sudo apt install docker.io

Docker starts by itself after installing and would keep its data on the
system disk. Stop it and switch off starting at boot; it will only run
when started with dk (step 3), with its data on the SSD:

  sudo systemctl disable --now docker.service docker.socket

Safety net: Docker refuses to start unless the SSD image is mounted.

  sudo mkdir -p /etc/systemd/system/docker.service.d
  printf '[Unit]\nConditionPathIsMountPoint=/var/lib/docker\n' |
      sudo tee /etc/systemd/system/docker.service.d/ssd.conf
  sudo systemctl daemon-reload


2. Docker's disk image on the SSD (once)
---------------------------------------
Open the SSD in the file manager so it is mounted, then check it:

  ls /run/media/theo/519CD9AD471916FF
  df -h /run/media/theo/519CD9AD471916FF        (needs 40 GB free)

If docker.img is not there yet, make it: a 40 GB file holding a Linux
(ext4) file system. It only uses space on the SSD as it fills.

  sudo truncate -s 40G /run/media/theo/519CD9AD471916FF/docker.img
  sudo mkfs.ext4 -F -L docker /run/media/theo/519CD9AD471916FF/docker.img

Clear what the install left on the system disk:

  sudo rm -rf /var/lib/docker
  sudo mkdir /var/lib/docker


3. The files, and the dk command
--------------------------------
  cd /run/media/theo/519CD9AD471916FF
  mkdir -p aneuu && cd aneuu
  tar -xzf ~/Downloads/aneuu-0.tar.gz --strip-components=1
  chmod +x mkiso avm dk
  mkdir -p ~/.local/bin && cp dk ~/.local/bin/

dk starts Docker on the SSD (dk off stops it, dk st shows the state):

  dk
  dk st          must say "on SSD" and show about 39G free
  sudo docker run --rm alpine:3.24 echo ok     must print: ok

After a reboot, or after plugging the SSD in again: open the SSD in the
file manager, then dk. Before unplugging the SSD: dk off.
Run everything below from the aneuu folder. The ISOs land in ./aneuu-out/.


4. First build: quick, without the kernel (about 20-40 minutes)
-------------------------------------------------------------
  sudo HAN_KERNEL=no sh mkiso 2>&1 | tee build-quick.log

This finds problems early. The ISO uses fbterm for Korean instead of the
cjktty kernel. Result: aneuu-out/aneuu-0-x86_64.iso
(Lines starting with "!!" are warnings: a skipped package, a failed patch.
 Look for them:  grep '!!' build-quick.log)


5. Full builds (about 2 hours each, mostly the kernel)
---------------------------------------------------------
  sudo sh mkiso 2>&1 | tee build-64.log                   # 64-bit
  sudo HAN_ARCH=x86 sh mkiso 2>&1 | tee build-32.log      # 32-bit

(Or both in one go: sudo HAN_ARCH="x86_64 x86" sh mkiso.)
Each build overwrites the ISO of the same name in aneuu-out/.
Note: settings go after sudo (sudo HAN_ARCH=...), not before it.


6. Install QEMU (once)
----------------------
  sudo apt install qemu-system-x86 qemu-utils ovmf dosfstools mtools
  sudo usermod -aG kvm "$USER"
  (log out and in again, so KVM makes the VM fast)


7. Test in the virtual machine
------------------------------
avm opens the VM in a window. "avm help" lists all the words.
Click inside the window to type. If Right Alt or the Hangul key switches
Xubuntu's own Korean input instead of Aneuu's, press Ctrl+Alt+G in the
QEMU window to grab the keyboard (Ctrl+Alt+G again releases it).

  a) Live boot (BIOS, 2 GB)             avm
     - log in as root (no password); Korean shows on the console
     - desk; F1 menu; F12 panel; F6/F7 copy and paste; Right Alt typing
     - doc (1 = 한국어), read a few topics
     - network is a cable in the VM:  ping -c 3 naver.com
     - han-add net, then han-yt 아이유 (video, and 3s sound only)
     - NetSurf (F1, B), mpv, fbi, hdos, cmus + alsamixer
     - QEMU menu Machine > Power Down = the power button: it must power off cleanly

  b) USB stick                          avm usb
     - husb; nnn /media/usb; the Korean file name shows; han-view on it
     - husb off

  c) Install to disk                    avm disk
     - hinst; pick the 20 GB disk (sda); yes; set a password; poweroff
     - then start the installed system:  avm hd
     - log in with the password; settings and Wi-Fi state survived
     - grep r900 /etc/apk/world   (kernel and NetSurf pinned)
     - apk update && apk upgrade  (must keep the Korean kernel: uname -r ends -900-lts)

  d) UEFI                               rm -f aneuu-disk.qcow2; avm uefi disk
     - same as c), then  avm uefi hd

  e) 32-bit, old netbook                avm 32 mem 2048
                                        avm 32 mem 2048 disk   then  avm 32 mem 2048 hd
     (Aneuu needs 2 GB of memory at least: avm 32 alone gives 1 GB)

  f) Bluetooth and Wi-Fi with real hardware
     lsusb                      find the device, e.g.  8087:0a2b Intel Bluetooth
     sudo avm pass 8087:0a2b    the VM gets it (Xubuntu loses it until the VM ends)
     - F8: pair headphones; play something; it must come out of the headphones
     - a USB Wi-Fi dongle the same way, then F5
     (A laptop's built-in Wi-Fi card is PCIe and cannot be passed this way.
      Sound under sudo is off in the VM; Bluetooth headphones still work.)

Not testable in a VM: battery, brightness keys, closing the lid, suspend,
built-in Wi-Fi. Those need a real laptop (step 8).

Start fresh any time: rm -f aneuu-disk*.qcow2 aneuu-usb.img aneuu-vars.fd


8. On a real laptop
-------------------
Copy the ISO to a Ventoy USB stick (or write it with dd), boot, and run
through 6a-6f again, plus Wi-Fi (F5), lid, battery in the status line.
The manual (dasi.epub) has the boot keys per laptop maker.


9. Free the space afterwards
----------------------------
  sudo docker system prune -af     (build containers and images; ISOs stay)
  dk off
