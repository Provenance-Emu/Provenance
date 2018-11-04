while read line
do
if [[ $line == addr:* ]] ; then addr=${line:6} ; offset=0; fi
if [[ $line == code:* ]] ; then code=${line:6} ; fi

if [[ $addr == $addr ]]
then
  if [[ $line == //h* ]]
   then
    echo $line | cut -f 4 -d ":" | perl -ne 's/([0-9a-f]{2})/print chr hex $1/gie' > block.bin
    bytes=`stat --printf="%s" block.bin`
    echo $offset
    offset=$(($offset + $bytes))
    arm-none-linux-gnueabi-objdump.exe -D -b binary  -marm block.bin  | cut -c 16- | tail -n+8
  else
    echo $line
  fi
fi
done