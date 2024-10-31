#!/bin/sh

# 3.2.30 on pandora has broken hugetlb
if [ "`uname -r`" != "3.2.30" ]; then
  # 2x2M hugepages should be enough
  sudo -n /usr/pandora/scripts/op_hugetlb.sh 4
fi

./PicoDrive "$@"

# restore stuff if pico crashes
./picorestore
sudo -n /usr/pandora/scripts/op_lcdrate.sh 60
sudo -n /usr/pandora/scripts/op_gamma.sh 0
sudo -n /usr/pandora/scripts/op_hugetlb.sh 0
