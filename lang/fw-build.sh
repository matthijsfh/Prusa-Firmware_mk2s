#!/bin/bash
#
# postbuild.sh - multi-language support script
#  Generate binary with secondary language.
#
# Input files:
#  $OUTDIR/Firmware.ino.elf
#  $OUTDIR/sketch/*.o (all object files)
#
# Output files:
#  text.sym
#  $PROGMEM.sym (progmem1.sym)
#  $PROGMEM.lss (...)
#  $PROGMEM.hex
#  $PROGMEM.chr
#  $PROGMEM.var
#  $PROGMEM.txt
#  textaddr.txt
#
#
# Config:
if [ -z "$CONFIG_OK" ]; then eval "$(cat config.sh)"; fi
if [ -z "$CONFIG_OK" ] | [ $CONFIG_OK -eq 0 ]; then echo 'Config NG!' >&2; exit 1; fi
#
# Selected language:
LNG=$1
#if [ -z "$LNG" ]; then LNG='cz'; fi
#
# Params:
IGNORE_MISSING_TEXT=1


finish()
{
 echo
 if [ "$1" = "0" ]; then
  echo "postbuild.sh finished with success" >&2
 else
  echo "postbuild.sh finished with errors!" >&2
 fi
 case "$-" in
  *i*) echo "press enter key"; read ;;
 esac
 exit $1
}

echo "postbuild.sh started" >&2

#check input files
echo " checking files:" >&2
if [ ! -e $OUTDIR ]; then echo "  folder '$OUTDIR' not found!" >&2; finish 1; fi
echo "  folder  OK" >&2
if [ ! -e $INOELF ]; then echo "  elf file '$INOELF' not found!" >&2; finish 1; fi
echo "  elf     OK" >&2
if ! ls $OBJDIR/*.o >/dev/null 2>&1; then echo "  no object files in '$OBJDIR/'!" >&2; finish 1; fi
echo "  objects OK" >&2

#run progmem.sh - examine content of progmem1
echo -n " running progmem.sh..." >&2
./progmem.sh 1 2>progmem.out
if [ $? -ne 0 ]; then echo "NG! - check progmem.out file" >&2; finish 1; fi
echo "OK" >&2

#run textaddr.sh - map progmem addreses to text identifiers
echo -n " running textaddr.sh..." >&2
./textaddr.sh 2>textaddr.out
if [ $? -ne 0 ]; then echo "NG! - check progmem.out file" >&2; finish 1; fi
echo "OK" >&2

#check for messages declared in progmem1, but not found in lang_en.txt
echo -n " checking textaddr.txt..." >&2
cat textaddr.txt | grep "^TEXT NF" | sed "s/[^\"]*\"//;s/\"$//" >not_used.txt
cat textaddr.txt | grep "^ADDR NF" | sed "s/[^\"]*\"//;s/\"$//" >not_tran.txt
if cat textaddr.txt | grep "^ADDR NF" >/dev/null; then
 echo "NG! - some texts not found in lang_en.txt!"
 if [ $IGNORE_MISSING_TEXT -eq 0 ]; then
  finish 1
 else
  echo "  missing text ignored!" >&2
 fi
else
 echo "OK" >&2
fi

#extract binary file
echo -n " extracting binary..." >&2
$OBJCOPY -I ihex -O binary $INOHEX ./firmware.bin
echo "OK" >&2

#update binary file
echo " updating binary:" >&2

#update progmem1 id entries in binary file
echo -n "  primary language ids..." >&2
cat textaddr.txt | grep "^ADDR OK" | cut -f3- -d' ' | sed "s/^0000/0x/" |\
 awk '{ id = $2 - 1; hi = int(id / 256); lo = int(id - 256 * hi); printf("%d \\\\x%02x\\\\x%02x\n", strtonum($1), lo, hi); }' |\
 while read addr data; do
  /bin/echo -n -e $data | dd of=./firmware.bin bs=1 count=2 seek=$addr conv=notrunc oflag=nonblock 2>/dev/null
 done
echo "OK" >&2

#update primary language signature in binary file
echo -n "  primary language signature..." >&2
if [ -e lang_en.bin ]; then
 #find symbol _PRI_LANG_SIGNATURE in section '.text'
 pri_lang=$(cat text.sym | grep -E "\b_PRI_LANG_SIGNATURE\b")
 if [ -z "$pri_lang" ]; then echo "NG!\n  symbol _PRI_LANG_SIGNATURE not found!" >&2; finish 1; fi
 #get pri_lang address
 pri_lang_addr='0x'$(echo $pri_lang | cut -f1 -d' ')
 #read header from primary language binary file
 header=$(dd if=lang_en.bin bs=1 count=16 2>/dev/null | xxd | cut -c11-49 | sed 's/\([0-9a-f][0-9a-f]\)[\ ]*/\1 /g')
 #read checksum and count data as 4 byte signature
 chscnt=$(echo $header | cut -c18-29 | sed "s/ /\\\\x/g")
 /bin/echo -e -n "$chscnt" |\
  dd of=firmware.bin bs=1 count=4 seek=$(($pri_lang_addr)) conv=notrunc 2>/dev/null
 echo "OK" >&2
else
 echo "NG! - file lang_en.bin not found!" >&2;
 finish 1
fi

#convert bin to hex
echo -n " converting to hex..." >&2
$OBJCOPY -I binary -O ihex ./firmware.bin ./firmware.hex
echo "OK" >&2

#update _SEC_LANG in binary file if language is selected
echo -n "  secondary language data..." >&2
if [ ! -z "$LNG" ]; then
 ./update_lang.sh $LNG 2>./update_lang.out
 if [ $? -ne 0 ]; then echo "NG! - check update_lang.out file" >&2; finish 1; fi
 echo "OK" >&2
 finish 0
else
 echo "Updating languages:" >&2
 if [ -e lang_cz.bin ]; then
  echo -n " Czech  : " >&2
  ./update_lang.sh cz 2>./update_lang_cz.out 1>/dev/null
  if [ $? -eq 0 ]; then echo 'OK' >&2; else echo 'NG!' >&2; finish 1; fi
 fi
 if [ -e lang_de.bin ]; then
  echo -n " German : " >&2
  ./update_lang.sh de 2>./update_lang_de.out 1>/dev/null
  if [ $? -eq 0 ]; then echo 'OK' >&2; else echo 'NG!' >&2; finish 1; fi
 fi
 if [ -e lang_it.bin ]; then
  echo -n " Italian: " >&2
  ./update_lang.sh it 2>./update_lang_it.out 1>/dev/null
  if [ $? -eq 0 ]; then echo 'OK' >&2; else echo 'NG!' >&2; finish 1; fi
 fi
 if [ -e lang_es.bin ]; then
  echo -n " Spanish: " >&2
  ./update_lang.sh es 2>./update_lang_es.out 1>/dev/null
  if [ $? -eq 0 ]; then echo 'OK' >&2; else echo 'NG!' >&2; finish 1; fi
 fi
 if [ -e lang_fr.bin ]; then
  echo -n " French : " >&2
  ./update_lang.sh fr 2>./update_lang_fr.out 1>/dev/null
  if [ $? -eq 0 ]; then echo 'OK' >&2; else echo 'NG!' >&2; finish 1; fi
 fi
 if [ -e lang_pl.bin ]; then
  echo -n " Polish : " >&2
  ./update_lang.sh pl 2>./update_lang_pl.out 1>/dev/null
  if [ $? -eq 0 ]; then echo 'OK' >&2; else echo 'NG!' >&2; finish 1; fi
 fi
#Community language support
#Dutch
 if [ -e lang_nl.bin ]; then
  echo -n " Dutch  : " >&2
  ./update_lang.sh nl 2>./update_lang_nl.out 1>/dev/null
  if [ $? -eq 0 ]; then echo 'OK' >&2; else echo 'NG!' >&2; fi
 fi

#aa
 if [ -e lang_aa.bin ]; then
  echo -n " AA  : " >&2
  ./update_lang.sh aa 2>./update_lang_aa.out 1>/dev/null
  if [ $? -eq 0 ]; then echo 'OK' >&2; else echo 'NG!' >&2; fi
 fi

#aa
 if [ -e lang_ab.bin ]; then
  echo -n " AB  : " >&2
  ./update_lang.sh ab 2>./update_lang_ab.out 1>/dev/null
  if [ $? -eq 0 ]; then echo 'OK' >&2; else echo 'NG!' >&2; fi
 fi

#aa
 if [ -e lang_ac.bin ]; then
  echo -n " AC  : " >&2
  ./update_lang.sh ac 2>./update_lang_ac.out 1>/dev/null
  if [ $? -eq 0 ]; then echo 'OK' >&2; else echo 'NG!' >&2; fi
 fi

#aa
 if [ -e lang_ad.bin ]; then
  echo -n " AD  : " >&2
  ./update_lang.sh ad 2>./update_lang_ad.out 1>/dev/null
  if [ $? -eq 0 ]; then echo 'OK' >&2; else echo 'NG!' >&2; fi
 fi

#aa
 if [ -e lang_ae.bin ]; then
  echo -n " AE  : " >&2
  ./update_lang.sh ae 2>./update_lang_ae.out 1>/dev/null
  if [ $? -eq 0 ]; then echo 'OK' >&2; else echo 'NG!' >&2; fi
 fi

#aa
 if [ -e lang_af.bin ]; then
  echo -n " AF  : " >&2
  ./update_lang.sh af 2>./update_lang_af.out 1>/dev/null
  if [ $? -eq 0 ]; then echo 'OK' >&2; else echo 'NG!' >&2; fi
 fi

#aa
 if [ -e lang_ag.bin ]; then
  echo -n " AG  : " >&2
  ./update_lang.sh ag 2>./update_lang_ag.out 1>/dev/null
  if [ $? -eq 0 ]; then echo 'OK' >&2; else echo 'NG!' >&2; fi
 fi

#aa
 if [ -e lang_ah.bin ]; then
  echo -n " AH  : " >&2
  ./update_lang.sh ah 2>./update_lang_ah.out 1>/dev/null
  if [ $? -eq 0 ]; then echo 'OK' >&2; else echo 'NG!' >&2; fi
 fi

#aa
 if [ -e lang_ai.bin ]; then
  echo -n " AI  : " >&2
  ./update_lang.sh ai 2>./update_lang_ai.out 1>/dev/null
  if [ $? -eq 0 ]; then echo 'OK' >&2; else echo 'NG!' >&2; fi
 fi

#aa
 if [ -e lang_aj.bin ]; then
  echo -n " AJ  : " >&2
  ./update_lang.sh aj 2>./update_lang_aj.out 1>/dev/null
  if [ $? -eq 0 ]; then echo 'OK' >&2; else echo 'NG!' >&2; fi
 fi

#aa
 if [ -e lang_ak.bin ]; then
  echo -n " AK  : " >&2
  ./update_lang.sh ak 2>./update_lang_ak.out 1>/dev/null
  if [ $? -eq 0 ]; then echo 'OK' >&2; else echo 'NG!' >&2; fi
 fi

#aa
 if [ -e lang_al.bin ]; then
  echo -n " AL  : " >&2
  ./update_lang.sh al 2>./update_lang_al.out 1>/dev/null
  if [ $? -eq 0 ]; then echo 'OK' >&2; else echo 'NG!' >&2; fi
 fi

#aa
 if [ -e lang_am.bin ]; then
  echo -n " AM  : " >&2
  ./update_lang.sh am 2>./update_lang_am.out 1>/dev/null
  if [ $? -eq 0 ]; then echo 'OK' >&2; else echo 'NG!' >&2; fi
 fi

#aa
 if [ -e lang_an.bin ]; then
  echo -n " AN  : " >&2
  ./update_lang.sh an 2>./update_lang_an.out 1>/dev/null
  if [ $? -eq 0 ]; then echo 'OK' >&2; else echo 'NG!' >&2; fi
 fi

#aa
 if [ -e lang_ao.bin ]; then
  echo -n " AO  : " >&2
  ./update_lang.sh ao 2>./update_lang_ao.out 1>/dev/null
  if [ $? -eq 0 ]; then echo 'OK' >&2; else echo 'NG!' >&2; fi
 fi

#aa
 if [ -e lang_ap.bin ]; then
  echo -n " AP  : " >&2
  ./update_lang.sh ap 2>./update_lang_ap.out 1>/dev/null
  if [ $? -eq 0 ]; then echo 'OK' >&2; else echo 'NG!' >&2; fi
 fi

#aa
 if [ -e lang_aq.bin ]; then
  echo -n " AQ  : " >&2
  ./update_lang.sh aq 2>./update_lang_aq.out 1>/dev/null
  if [ $? -eq 0 ]; then echo 'OK' >&2; else echo 'NG!' >&2; fi
 fi

#aa
 if [ -e lang_ar.bin ]; then
  echo -n " AR  : " >&2
  ./update_lang.sh ar 2>./update_lang_ar.out 1>/dev/null
  if [ $? -eq 0 ]; then echo 'OK' >&2; else echo 'NG!' >&2; fi
 fi

#aa
 if [ -e lang_as.bin ]; then
  echo -n " AS  : " >&2
  ./update_lang.sh as 2>./update_lang_as.out 1>/dev/null
  if [ $? -eq 0 ]; then echo 'OK' >&2; else echo 'NG!' >&2; fi
 fi

#aa
 if [ -e lang_at.bin ]; then
  echo -n " AT  : " >&2
  ./update_lang.sh at 2>./update_lang_at.out 1>/dev/null
  if [ $? -eq 0 ]; then echo 'OK' >&2; else echo 'NG!' >&2; fi
 fi

#aa
 if [ -e lang_au.bin ]; then
  echo -n " AU  : " >&2
  ./update_lang.sh au 2>./update_lang_au.out 1>/dev/null
  if [ $? -eq 0 ]; then echo 'OK' >&2; else echo 'NG!' >&2; fi
 fi

#aa
 if [ -e lang_av.bin ]; then
  echo -n " AV  : " >&2
  ./update_lang.sh av 2>./update_lang_av.out 1>/dev/null
  if [ $? -eq 0 ]; then echo 'OK' >&2; else echo 'NG!' >&2; fi
 fi

#aa
 if [ -e lang_aw.bin ]; then
  echo -n " AW  : " >&2
  ./update_lang.sh aw 2>./update_lang_aw.out 1>/dev/null
  if [ $? -eq 0 ]; then echo 'OK' >&2; else echo 'NG!' >&2; fi
 fi

#aa
 if [ -e lang_ax.bin ]; then
  echo -n " AX  : " >&2
  ./update_lang.sh ax 2>./update_lang_ax.out 1>/dev/null
  if [ $? -eq 0 ]; then echo 'OK' >&2; else echo 'NG!' >&2; fi
 fi

#aa
 if [ -e lang_ay.bin ]; then
  echo -n " AY  : " >&2
  ./update_lang.sh ay 2>./update_lang_ay.out 1>/dev/null
  if [ $? -eq 0 ]; then echo 'OK' >&2; else echo 'NG!' >&2; fi
 fi

#aa
 if [ -e lang_az.bin ]; then
  echo -n " AZ  : " >&2
  ./update_lang.sh az 2>./update_lang_az.out 1>/dev/null
  if [ $? -eq 0 ]; then echo 'OK' >&2; else echo 'NG!' >&2; fi
 fi

#Use the 6 lines below as a template and replace 'qr' and 'New language'
#New language
# if [ -e lang_qr.bin ]; then
#  echo -n " New language  : " >&2
#  ./update_lang.sh qr 2>./update_lang_qr.out 1>/dev/null
#  if [ $? -eq 0 ]; then echo 'OK' >&2; else echo 'NG!' >&2; fi
# fi

# echo "skipped" >&2
fi

#create binary file with all languages
rm -f lang.bin
if [ -e lang_cz.bin ]; then cat lang_cz.bin >> lang.bin; fi
if [ -e lang_de.bin ]; then cat lang_de.bin >> lang.bin; fi
if [ -e lang_es.bin ]; then cat lang_es.bin >> lang.bin; fi
if [ -e lang_fr.bin ]; then cat lang_fr.bin >> lang.bin; fi
if [ -e lang_it.bin ]; then cat lang_it.bin >> lang.bin; fi
if [ -e lang_pl.bin ]; then cat lang_pl.bin >> lang.bin; fi
#Community language support
# Dutch
if [ -e lang_nl.bin ]; then cat lang_nl.bin >> lang.bin; fi

if [ -e lang_aa.bin ]; then cat lang_aa.bin >> lang.bin; fi
if [ -e lang_ab.bin ]; then cat lang_ab.bin >> lang.bin; fi
if [ -e lang_ac.bin ]; then cat lang_ac.bin >> lang.bin; fi
if [ -e lang_ad.bin ]; then cat lang_ad.bin >> lang.bin; fi
if [ -e lang_ae.bin ]; then cat lang_ae.bin >> lang.bin; fi
if [ -e lang_af.bin ]; then cat lang_af.bin >> lang.bin; fi
if [ -e lang_ag.bin ]; then cat lang_ag.bin >> lang.bin; fi
if [ -e lang_ah.bin ]; then cat lang_ah.bin >> lang.bin; fi
if [ -e lang_ai.bin ]; then cat lang_ai.bin >> lang.bin; fi
if [ -e lang_aj.bin ]; then cat lang_aj.bin >> lang.bin; fi
if [ -e lang_ak.bin ]; then cat lang_ak.bin >> lang.bin; fi
if [ -e lang_al.bin ]; then cat lang_al.bin >> lang.bin; fi
if [ -e lang_am.bin ]; then cat lang_am.bin >> lang.bin; fi
if [ -e lang_an.bin ]; then cat lang_an.bin >> lang.bin; fi
if [ -e lang_ao.bin ]; then cat lang_ao.bin >> lang.bin; fi
if [ -e lang_ap.bin ]; then cat lang_ap.bin >> lang.bin; fi
if [ -e lang_aq.bin ]; then cat lang_aq.bin >> lang.bin; fi
if [ -e lang_ar.bin ]; then cat lang_ar.bin >> lang.bin; fi
if [ -e lang_as.bin ]; then cat lang_as.bin >> lang.bin; fi
if [ -e lang_at.bin ]; then cat lang_at.bin >> lang.bin; fi
if [ -e lang_au.bin ]; then cat lang_au.bin >> lang.bin; fi
if [ -e lang_av.bin ]; then cat lang_av.bin >> lang.bin; fi
if [ -e lang_aw.bin ]; then cat lang_aw.bin >> lang.bin; fi
if [ -e lang_ax.bin ]; then cat lang_ax.bin >> lang.bin; fi
if [ -e lang_ay.bin ]; then cat lang_ay.bin >> lang.bin; fi
if [ -e lang_az.bin ]; then cat lang_az.bin >> lang.bin; fi

#Use the 2 lines below as a template and replace 'qr'
## New language
#if [ -e lang_qr.bin ]; then cat lang_qr.bin >> lang.bin; fi

#convert lang.bin to lang.hex
echo -n " converting to hex..." >&2
$OBJCOPY -I binary -O ihex ./lang.bin ./lang.hex
echo "OK" >&2

#append languages to hex file
cat ./lang.hex >> firmware.hex

finish 0
