# dyne:II startup scripts
# (C) 2005 Denis "jaromil" Rojo
# GNU GPL License

# this script handles the default procedures for starting x
# choosing a windowmaker, it will generate volumes entries in the dock
# as well application entries for the menu

# a la dyne staila :)

# a volume entry is one line:
# hdisk|floppy|cd|usb  /dev/ice  /vol/mountpoint  filesystem  [sys|rem]

source /lib/dyne/utils.sh

# ROX paths
ROXPDTMP=/var/run/rox_pan_Default
ROXICONSTMP=/var/run/rox_globicons
ROXPD=/etc/xdg/rox.sourceforge.net/ROX-Filer/pan_Default
ROXICONS=/etc/xdg/rox.sourceforge.net/ROX-Filer/globicons

# Window Maker paths
WMSTATETMP=/tmp/WMState
WMSTATEDOCK=/var/run/WMState.dock
WMSTATE=/etc/WindowMaker/WMState
WMMENU=/etc/WindowMaker/WMRootMenu

# Fluxbox paths
FLXMENU=/etc/fluxbox/menu

check_app_entry() {
# usage:
# check_app_entry  single_line_from_applist  file_to_write
# (used internally for check_apps_present)

     l=$1
     d=$2

     if [ "`echo ${l[1]}`" = "#" ]; then
       continue     # skip comments
     fi

     # pass nesting tags
     if [ "`echo $l | cut -f1 -d'|'`" = "Begin" ]; then
       echo "$l" >> $d
       continue
     fi

     if [ "`echo $l | cut -f1 -d'|'`" = "End" ]; then
       echo "$l" >> $d
       continue
     fi

     # pass special entries
     if [ "$l" = "DESKTOP" ]; then
       echo "$l" >> $d
       continue
     fi

     # and now check the applications
     APP="`echo $l | cut -f3 -d'|' | awk '{print $1}'`"
     which $APP    1>/dev/null     2>/dev/null
     if [ $? = 0 ]; then
       echo "$l" >> $d
     fi

}

check_apps_present() {
# parses /lib/dyne/dyne.applist and checks wich applications are present
# prints out a list of applications present in /boot/dyne.apps

# the order is given by the configuration directive: menu_sections
# it can contain a list of module names

  # load common environment
  source /lib/dyne/zsh/common
  # load dyne modules paths
  source /boot/dynenv.modules

  if [ $1 ]; then
    APPS=$1
  else
    APPS=/boot/dyne.apps
  fi

  if [ -w $APPS ]; then
    rm    $APPS
  fi

  echo "# list of applications detected in the current dyne system" \
       >  $APPS
  echo "# automatically generated at boot" >> /boot/dyne.apps
  echo >> $APPS

  # if modules contain etc/applist then process it first
  # this way modules can provide their own description for applications
  # and have a separated menu entry for them.
  for mod in `ls /opt`; do
    if [ -r /opt/$mod/etc/applist ]; then
      LINE=`cat /opt/$mod/etc/applist`
      for l in ${(f)LINE}; do
        check_app_entry $l $APPS
      done
    fi
  done

  LINE=`cat /lib/dyne/dyne.applist`
  for l in ${(f)LINE}; do
    check_app_entry $l $APPS
  done

}

fluxbox_gen_menu() {

    mkdir -p /etc/fluxbox

    if [ $1 ]; then
      APPS=$1
    else
      APPS=/boot/dyne.apps
    fi

    if [ ! -r $APPS ]; then
       notice "scanning for applications installed, please wait..."
       check_apps_present $APPS
    fi

    if [ -r $FLXMENU ]; then
       rm $FLXMENU
    fi

    cat $APPS \
    | awk -f /lib/dyne/menugen.awk -v render=fluxbox \
    > $FLXMENU

    # now append the static entries: xutils, desktop, exit
    cat /lib/dyne/menu.fluxbox >> $FLXMENU
    # and close up the menu
    echo "[end]" >> $FLXMENU

}

wmaker_gen_menu() {

    if [ $1 ]; then
      APPS=$1
    else
      APPS=/boot/dyne.apps
    fi

    if [ ! -r $APPS ]; then
       notice "scanning for applications installed, please wait..."
       check_apps_present $APPS
    fi

    if [ -r $WMMENU ]; then
       rm $WMMENU
    fi

    cat /boot/dyne.apps \
    | awk -f /lib/dyne/menugen.awk -v render=wmaker \
    > $WMMENU


    # now append the static entries: xutils, desktop, exit
    cat /lib/dyne/menu.wmaker >> $WMMENU
    # and close up the menu
    echo ")" >> $WMMENU

    # here overwrites previous or user defined menu
    if [ -r /root/GNUstep/Defaults/WMRootMenu ]; then
       rm /root/GNUstep/Defaults/WMRootMenu
    fi
    cp $WMMENU /root/GNUstep/Defaults/WMRootMenu
    for u in `ls /home`; do
       if [ -r /home/$u/GNUstep/Defaults/WMRootMenu ]; then
          rm /home/$u/GNUstep/Defaults/WMRootMenu
       fi
       cp $WMMENU /home/$u/GNUstep/Defaults/WMRootMenu
    done

}


# ROX filer
rox_gen_volumes() {

    act "generating ROX Filer setup"

    if [ -r $ROXPDTMP    ]; then rm $ROXPDTMP; fi
    if [ -r $ROXICONSTMP ]; then rm $ROXICONSTMP;   fi

    # generate the list of harddisks
    HDISKS=`cat /boot/volumes | grep "^hdisk" | awk '{print $3}' | cut -d/ -f3 | uniq`


    # the panel
    cat <<EOF > $ROXPDTMP
<?xml version="1.0"?>
<panel side="Right">
<start>
<icon label="dyne:II">/bin/dynesplash</icon>
EOF

    # the icons
    cat <<EOF > $ROXICONSTMP
<?xml version="1.0"?>
<special-files>
<rule match="/bin/dynesplash"> <icon>/usr/share/dyne/splash/logo-sm.png</icon> </rule>
<rule match="/bin/gohome"> <icon>/usr/share/icons/graphite/48x48/filesystems/gnome-fs-home.png</icon> </rule>
EOF


    # panel
    echo $HDISKS | awk '{ print "  <icon label=\"HD " NR "\">/mnt/" $1 "</icon>" }' \
                       >> $ROXPDTMP

    # icons
    echo $HDISKS | awk '{ print "<rule match=\"/mnt/" $1 "\"> <icon>/usr/share/icons/graphite/48x48/filesystems/gnome-fs-blockdev.png</icon> </rule>" }' >> $ROXICONSTMP

    # partitions
    cat /boot/volumes | grep "^hdisk" | awk '{ print "<rule match=\"" $3 "\"> <icon>/usr/share/icons/graphite/48x48/apps/drawer.png</icon> </rule>" }' >> $ROXICONSTMP


    # then all the rest
    # panel
    cat /boot/volumes | grep -v "^hdisk" | awk '
        /^floppy/ {  print "  <icon label=\"Floppy\">" $3 "</icon>" }
        /^usb/    {  print "  <icon label=\"Usb\">" $3 "</icon>"    }
        /^cd/     {  print "  <icon label=\"CD\">" $3 "</icon>"     }
        /^dvd/    {  print "  <icon label=\"DVD\">" $3 "</icon>"    }
        ' >> $ROXPDTMP

    # icons
    cat /boot/volumes | grep -v "^hdisk" | awk '
        /^floppy/ { print "<rule match=\"" $3 "\"><icon>/usr/share/icons/graphite/48x48/devices/gnome-dev-floppy.png</icon></rule>" }
        /^cd/     { print "<rule match=\"" $3 "\"><icon>/usr/share/icons/graphite/48x48/devices/gnome-dev-cdrom.png</icon></rule>" }
        /^dvd/    { print "<rule match=\"" $3 "\"><icon>/usr/share/icons/graphite/48x48/devices/gnome-dev-dvdr.png</icon></rule>" }
        /^usb/    { print "<rule match=\"" $3 "\"><icon>/usr/share/icons/crystalsvg/48x48/devices/usbpendrive_unmount.png</icon></rule>" }
        ' >> $ROXICONSTMP

    # local area network, check IANA assigned private ips:
#    LAN=`ifconfig | awk '/inet addr.*192.168/ { print "true"; exit }
#                         /inet addr.*10./     { print "true"; exit }
#                         /inet addr.*172.16/  { print "true"; exit }'`
    LAN=`lspci | grep -i 'ethernet'`
    if [ $LAN ]; then
      echo "<icon label=\"Lan\">/usr/bin/LinNeighborhood</icon>" >> $ROXPDTMP
      echo "<rule match=\"/usr/bin/LinNeighborhood\"><icon>/usr/share/icons/graphite/48x48/filesystems/gnome-fs-network.png</icon></rule>" >> $ROXICONSTMP
      echo "<rule match=\"/mnt/shares\"><icon>/usr/share/icons/graphite/48x48/filesystems/gnome-fs-network.png</icon></rule>" >> $ROXICONSTMP
    fi

    # add some more icons for the filesystem
    cat <<EOF >> $ROXICONSTMP
<rule match="/home"><icon>/usr/share/icons/graphite/48x48/stock/generic/stock_home.png</icon></rule>
<rule match="/root"><icon>/usr/share/icons/graphite/48x48/stock/generic/stock_home.png</icon></rule>
<rule match="/bin"><icon>/usr/share/icons/graphite/48x48/apps/gnome-run.png</icon></rule>
<rule match="/sbin"><icon>/usr/share/icons/graphite/48x48/apps/gnome-run.png</icon></rule>
<rule match="/lib"><icon>/usr/share/icons/graphite/48x48/apps/gnome-run.png</icon></rule>
<rule match="/usr"><icon>/usr/share/icons/graphite/48x48/apps/gnome-run.png</icon></rule>
<rule match="/opt"><icon>/usr/share/dyne/logo.png</icon></rule>
<rule match="/usr/share"><icon>/usr/share/icons/graphite/48x48/apps/gnome-other.png</icon></rule>
<rule match="/usr/sbin"><icon>/usr/share/icons/graphite/48x48/apps/gnome-run.png</icon></rule>
<rule match="/usr/bin"><icon>/usr/share/icons/graphite/48x48/apps/gnome-run.png</icon></rule>
<rule match="/usr/lib"><icon>/usr/share/icons/graphite/48x48/apps/gnome-run.png</icon></rule>
<rule match="/usr/doc"><icon>/usr/share/icons/graphite/48x48/stock/generic/stock_example.png</icon></rule>
<rule match="/etc"><icon>/usr/share/icons/graphite/48x48/apps/gnome-settings.png</icon></rule>
<rule match="/dev"><icon>/usr/share/icons/graphite/48x48/apps/hwbrowser.png</icon></rule>
<rule match="/sys"><icon>/usr/share/icons/graphite/48x48/apps/hwbrowser.png</icon></rule>
<rule match="/proc"><icon>/usr/share/icons/graphite/48x48/apps/hwbrowser.png</icon></rule>
<rule match="/boot"><icon>/usr/share/icons/graphite/48x48/apps/hwbrowser.png</icon></rule>
<rule match="/var"><icon>/usr/share/icons/graphite/48x48/apps/hwbrowser.png</icon></rule>
EOF
    # close the panel
    echo "</start>" >> $ROXPDTMP
    echo "<end/>" >> $ROXPDTMP
    echo "</panel>" >> $ROXPDTMP

    # close the icons
    echo "</special-files>" >> $ROXICONSTMP

    cp $ROXPDTMP    $ROXPD
    cp $ROXICONSTMP $ROXICONS
}

# Window Maker
wmaker_gen_volumes() {
# this functions generates the right hand dock for wmaker

    if [ -r $WMSTATEDOCK ]; then rm $WMSTATEDOCK; fi

    # generate the list of harddisks
    HDISKS=`cat /boot/volumes | grep "^hdisk" | awk '{print $3}' | cut -d/ -f3 | uniq`


    # put the header
    cat <<EOF > $WMSTATEDOCK
  Dock = {
    Lowered = Yes;
    Position = "-64,0";
    Applications = (
      {
        Name = Dyne;
        Lock = Yes;
        AutoLaunch = Yes;
        Command = dynesplash;
        Position = "0,0";
        Forced = No;
        BuggyApplication = No;
      },
      {
        Name = Home;
        Lock = Yes;
        AutoLaunch = No;
        Command = "rox";
        Position = "0,1";
        Forced = No;
        BuggyApplication = No;
      }
EOF

    echo $HDISKS | awk '
{
print ","
print "{"
print "Name = \"Hd" NR ".HardDisk\";"
print "Lock = yes;"
print "Autolaunch = no;"
print "Command = \"rox /mnt/" $1 "\";"
print "Position = \"0," NR+1 "\";"
print "Forced = no;";
print "BuggyApplication = no;"
print "}"
}
' >> $WMSTATEDOCK

    POS=`echo $HDISKS | wc -l` # how many harddisks are up there?
    POS=`expr $POS + 2` # get on the next position in dock

    LAN=`lspci | grep -i 'ethernet'`
    if [ $LAN ]; then
       cat <<EOF >>$WMSTATEDOCK
,
{
Name = "Samba.Network";
Lock = yes;
Autolaunch = no;
Command = "rox /mnt/shares";
Position = "0,$POS";
Forced = no;
BuggyApplication = no;
}
EOF
#      POS=`expr $POS + 1` # advance a position in dock
    fi


cat /boot/volumes | grep -v '^hdisk' | awk -v pos=$POS '
/^floppy/ {
print ","
print "{"
print "Name = \"Floppy" NR ".FloppyDisk\";"
print "Lock = yes;"
print "Autolaunch = no;"
print "Command = \"rox " $3 "\";"
print "Position = \"0," NR+pos "\";"
print "Forced = no;"
print "BuggyApplication = no;"
print "}"
}

/^usb/ {
print ","
print "{"
print "Name = \"Usb" NR ".UsbStorage\";"
print "Lock = yes;"
print "Autolaunch = no;"
print "Command = \"rox " $3 "\";"
print "Position = \"0," NR+pos "\";"
print "Forced = no;"
print "BuggyApplication = no;"
print "}"
}

/^cdrom/ {
print ","
print "{"
print "Name = \"Cd" NR ".CdRom\";"
print "Lock = yes;"
print "Autolaunch = no;"
print "Command = \"rox " $3 "\";"
print "Position = \"0," NR+pos "\";"
print "Forced = no;"
print "BuggyApplication = no;"
print "}"
}
' >> $WMSTATEDOCK

    echo "    );" >> $WMSTATEDOCK # close Applications = (
    echo "  };"   >> $WMSTATEDOCK # close Dock = {

    if [ -r $WMSTATE ]; then # WMState is already present
      # we are in a nest, so here we need to substitute only the Dock = { }; section
      # and leave all the rest intact (Clip, Workspaces)
      act "updating existing windowmaker dock"

      # Warning: this currently assumes that the Dock block is at beginning of WMState
      cat $WMSTATE | awk '
           /Dock = {/ { dockstart=NR }
                      { if(!dockstart) print $0 }' > $WMSTATETMP

      cat $WMSTATEDOCK                            >> $WMSTATETMP

      cat $WMSTATE | awk '
           /};/       { dockend=NR; next }
                      { if(dockend) print $0 }'   >> $WMSTATETMP

      cp -f $WMSTATETMP $WMSTATE
      rm -f $WMSTATETMP

      # overwrite docks in nest with the fresh one
      mkdir -p /root/GNUstep/Defaults
      cp -f $WMSTATE /root/GNUstep/Defaults/WMState
      for u in `ls /home`; do
        mkdir -p /home/${u}/GNUstep/Defaults
        cp -f $WMSTATE /home/${u}/GNUstep/Defaults/WMState
      done

    else

      # this is a freshly generated WMState, add other default sections
      act "generating a fresh windowmaker dock"
      echo "{" > $WMSTATE

      cat $WMSTATEDOCK >> $WMSTATE

      cat <<EOF >> $WMSTATE
  Workspace = "DESK 1";
  Workspaces = (
    {
      Name = "DESK 1";
    },
    {
      Name = "DESK 2";
    },
    {
      Name = "DESK 3";
    },
    {
      Name = "DESK 4";
    },
    {
      Name = "DESK 5";
    },
    {
      Name = "DESK 6";
    }
  );
  Applications = ();
}
EOF

    fi
}


# this function is called at the end of bootstrap.sh
# it starts up X with the current configuration
bootstrap_x() {

  source /etc/zshenv

  # remote X client-server
  XREMOTE="`get_config x_remote`"
  if [ $XREMOTE ]; then
    su -c X -indirect -query ${XREMOTE} &
    sleep 5
    xpid=`pidof X`
    if [ $xpid ]; then
      rm -f /tmp/.booting_x
    fi
    return
  fi

  USERLOGIN="`get_config user`"

  if ! [ $USERLOGIN ]; then

    # login directly into the desktop as root
    su - root -c xinit &

  elif [ $USERLOGIN = multi ]; then

    # popup a login prompt
    xdm

  elif [ `grep $USERLOGIN /etc/passwd` ]; then

    # login directly selected user
    su - $USERLOGIN -c xinit &
    
  else

    # login directly into the desktop as root
    su - root -c xinit &

  fi

  # delete booting_x to signal we have succesfully started X
  # dyne_startx is executed after login
  sleep 5
  xpid=`pidof X`
  if [ $xpid ]; then
    rm -f /tmp/.booting_x
  fi
 
}

# this function is called in .xinitrc by default
dyne_startx() {
  # source /etc/LANGUAGE

  # honour configuration directives
  # sent thru kernel parameters and dyne.cfg

  if [ $START_X11VNC = true ]; then
    (sleep 10; x11vnc -shared -forever -display :0)&
  fi

  # success booting x with current drivers:
  rm -f /tmp/.booting_x


  startx=`get_config startx`
  if [ $startx ]; then
    exec $startx
    return
  fi



  if ! [ $WINDOWMANAGER ]; then # no .xinitrc user setting
    WINDOWMANAGER=`get_config window_manager`
    if ! [ $WINDOWMANAGER ]; then # and no dyne.cfg
      # our default stays WindowMaker
      WINDOWMANAGER=wmaker
    fi
  fi

  # prepare ROX filer for its first start
  mkdir -p $HOME/.config/rox.sourceforge.net/ROX-Filer

  if [ $WINDOWMANAGER = fluxbox ]; then

    # start the system resource monitor
    # gkrellm -w -t /usr/share/gkrellm2/Egan &

    # the multiple desktop pager
    (sleep 10; fbpager -w &)&

    # our beloved splashscreen
    if ! [ -r $HOME/.nosplash ]; then
       dynesplash &
    fi

    # start our ROX filer with pinboard and panel
    (sleep 3; rox -p Default -r Default &)&

  fi

  # turn off the screensaver
  (sleep 1; xset s off -dpms &)&

  source /etc/LANGUAGE

  if [ $KEYB ]; then
    (sleep 2; /usr/X11R6/bin/setxkbmap $KEYB &)&
  fi


  # and the window manager
  exec $WINDOWMANAGER
}


