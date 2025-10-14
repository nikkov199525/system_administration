# Отчет
# По лабораторной работе № 7

Выполнил студент
Ковалев Никита, группа p4250  
Дата выполнения задания: 12.10.2025  
Наименование дисциплины: системное администрирование

## Лабораторная работа тюнинг ядра и GRUB

## Цель
Познакомиться с параметрами ядра Linux и загрузчиком **GRUB**:
- понять, как ядро принимает параметры при старте системы;
- научиться проверять, какие параметры реально применяются;
- разобраться в назначении параметров производительности и безопасности.
## Задание
1. Откройте файл `/etc/default/grub`.
- Найдите строки `GRUB_CMDLINE_LINUX_DEFAULT` и `GRUB_CMDLINE_LINUX`.  
- Добавьте туда следующие параметры:
     ```
     intel_idle.max_cstate=0 noinvpcid nopcid nopti nospectre_v2 processor.max_cstate=1 apparmor=0
     ```
   - Объясните: почему параметры разделяются пробелом, а не запятой?
Перед выполнением данного задания нужно выполнить резервную копию конфигурационного файла grub. Если вдруг что- то пойдет не так, нужно иметь возможность откатить все изменения. 
```bash
sudo cp /etc/default/grub /etc/default/grub.bak
```
Далее открываем файл
```bash
sudo nano /etc/default/grub
```
и меняем указанные параметры.
Каждый параметр передаётся ядру как отдельный аргумент командной строки.
Запятые применяются внутри одного параметра, если он принимает список значений.
Фрагмент измененного файла grub:
```ini
GRUB_DISTRIBUTOR=`lsb_release -i -s 2> /dev/null || echo Debian`
GRUB_CMDLINE_LINUX_DEFAULT="quiet intel_idle.max_cstate=0 noinvpcid nopcid nopti nospectre_v2 processor.max_cstate=1 apparmor=0"
GRUB_CMDLINE_LINUX="intel_idle.max_cstate=0 noinvpcid nopcid nopti nospectre_v2 processor.max_cstate=1 apparmor=0"
```




2. Обновите конфигурацию grub:  
````
sudo update-grub

Результат выполнения команды:
```bash
 Generating grub configuration file ...                                          
 Found background image: /usr/share/images/desktop-base/desktop-grub.png         
 Found linux image: /boot/vmlinuz-6.1.0-40-amd64                                 
 Found initrd image: /boot/initrd.img-6.1.0-40-amd64                             
 Found linux image: /boot/vmlinuz-6.1.0-9-amd64                                  
 Found initrd image: /boot/initrd.img-6.1.0-9-amd64                              
 Warning: os-prober will not be executed to detect other bootable partitions.    
 Systems on them will not be added to the GRUB boot configuration.               
 Check GRUB_DISABLE_OS_PROBER documentation entry.                               
```


3. Перезагрузите систему.  
После загрузки проверьте:
- что реально применилось (`cat /proc/cmdline`);  
- какие параметры поддерживаются:
  - через директории `/sys/module/*/parameters/`;  
  - через содержимое `/proc/sys/*`.

Перезагружаем систему нехитрым способом
```bash
sudo reboot
```

И в терминале выполняем команды:
```bash
cat /proc/cmdline || tee  kernelparameters.log
 BOOT_IMAGE=/boot/vmlinuz-6.1.0-40-amd64 root=UUID=ac3b8234-3aa7-449b-8ec6-eb5389
 e88b79 ro intel_idle.max_cstate=0 noinvpcid nopcid nopti nospectre_v2 processor.
 max_cstate=1 apparmor=0 quiet intel_idle.max_cstate=0 noinvpcid nopcid nopti nos
 pectre_v2 processor.max_cstate=1 apparmor=0                                     

ls /sys/module/intel_idle/parameters/

 max_cstate  no_acpi  preferred_cstates  states_off  use_acpi                    


ls /sys/module/processor/parameters/                             

 bm_check_disable  ignore_ppc  ignore_tpc  latency_factor  max_cstate  nocst     

ls /sys/module/apparmor/parameters/                              

 audit         enabled        lock_policy  paranoid_load                         
 audit_header  export_binary  logsyscall   path_max                              
 debug         hash_policy    mode         rawdata_compression_level             




cat /sys/module/intel_idle/parameters/max_cstate

 0                                                                               

sudo cat /sys/module/processor/parameters/max_cstate

 1                                                                               

cat /sys/module/apparmor/parameters/enabled
 N                                                                               
grep . /sys/devices/system/cpu/vulnerabilities/*

```
/sys/devices/system/cpu/vulnerabilities/gather_data_sampling:Unknown: Dependent on hypervisor status
/sys/devices/system/cpu/vulnerabilities/indirect_target_selection:Vulnerable
/sys/devices/system/cpu/vulnerabilities/itlb_multihit:Not affected
/sys/devices/system/cpu/vulnerabilities/l1tf:Mitigation: PTE Inversion
/sys/devices/system/cpu/vulnerabilities/meltdown:Vulnerable
/sys/devices/system/cpu/vulnerabilities/spectre_v2:Vulnerable; IBPB: disabled; STIBP: disabled; PBRSB-eIBRS: Not affected; BHI: Vulnerable
```




4. Сравните список:  
- какие параметры реально учтены;  
- какие проигнорированы (ядро не знает или модуль отсутствует).  
* Все параметры успешно переданы ядру и видны в /proc/cmdline.
* Параметры, связанные с управлением энергопотреблением и AppArmor, применились, а параметры безопасности, связанные с уязвимостями Spectre/Meltdown, частично поддерживаются, однако некоторые уязвимости остаются.
Ниже приводится таблица с параметрами и их назначением.
| Параметр                | Поддерживается? | Назначение                                                               |
| ----------------------- | --------------- | ------------------------------------------------------------------------ |
| intel_idle.max_cstate=0 | да              | Отключает глубокие C-состояния энергосбережения через драйвер intel_idle |
| processor.max_cstate=1  | да              | Ограничивает глубину сна CPU на уровне модуля processor                  |
| apparmor=0              | да              | Отключает систему мандатного контроля AppArmor                           |
| noinvpcid               | частично   | Старый параметр TLB-оптимизаций, в новых ядрах часто игнорируется        |
| nopcid                  | частично | Отключение PCID, может игнорироваться ядром Debian 12                    |
| nopti                   | да              | Отключает Page Table Isolation (механизм защиты от Meltdown)             |
| nospectre_v2            | да              | Отключает защиту от уязвимости Spectre v2                                |
---
