# Отчет
# По работе от 02.09.2025


Ковалев Никита  
Группа: p4250  
Дата выполнения задания: 05.09.2025  
Именование дисциплины: системное администрирование

### Задание 1. SSH

Перенести SSH на порт от 10000 до 65535.
Создать нового пользователя с правами sudo.
Полностью отключить root для входа.
Запретить вход по паролю, оставить только ключи.
Проверить подключение по ключу к новому пользователю.

В терминале:
   ```bash
   sudo nano /etc/ssh/sshd_config
   ```

В файле были изменены параметры:
   ```ini
   Port 30781
   PermitRootLogin no
   PasswordAuthentication no
   ```
Примечание: первый  и третий параметры в моем случае были закомментированы.

Затем:
   ```bash
   sudo adduser admin
   sudo usermod -aG sudo admin
   sudo systemctl restart ssh
   ```
Теперь нужно подключиться к серверу по ssh при помощи ssh- ключей.
Генерация SSH-ключей 
На Windows ключи можно сгенерировать при помощи puttygen.
Процесс несложный. Запускаем утилиту puttygen, жмем "Generrate", водим мышкой по окну программы (весь процесс можно выполнить даже при использовании NVDA), затем из поля "Public key for pasting into OpenSSH authorized_keys file" копируем все содержимое куда-нибудь, оно понадобится дальше. затем сохраняем ключ на компьютере через "file/Save public key".
А теперь в Linux:
   ```bash
   mkdir -p /home/admin/.ssh
   echo "Ваш_скопированный_из_буфера_обмена_публичный_ключ" >> /home/admin/.ssh/authorized_keys
   chown -R admin:admin /home/admin/.ssh
   chmod 700 /home/admin/.ssh
   chmod 600 /home/admin/.ssh/authorized_keys
   ```
Теперь открываем putty, вводим ip-адрес и порт, в моем случае адрес 192.168.0.109 и порт 30781
Затем в дереве нужно найти "connection" и там выбрать  "data" и в поле Auto-login username ввести имя нашего пользователя.
Затем в дереве нужно перейти в "Connection" -> "SSH" -> "Auth" -> "Credentials"и через кнопку "Browse..." выбрать закрытый ключ.
В моем случае результат такой:
admin@orangepi3b:~$
Теперь можно с этим работать.
---

### Задание 2. iptables

Разрешить только loopback, установленные соединения и SSH.
Проверить открытые порты через `nmap`.
Сохранить правила iptables и проверить их после перезагрузки.
Разрешаем только loopback, установленные соединения, SSH и порт 80
   ```bash
   sudo iptables -A INPUT -i lo -j ACCEPT
   sudo iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
   sudo iptables -A INPUT -p tcp --dport 30781 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 80 -j ACCEPT
   sudo iptables -A INPUT -j DROP
   ```
Пояснения.
делает так, чтобы локальные процессы могли общаться между собой.
Второй командой мы разрешаем прием ответов для установленных соединений
Третья и четвертая команды- разрешаем входящие соединения на нестандартный порт ssh и на порт 80.
пятая команда. Просто молча отбрасываем все, что не касается наших правил.
Проверяем открытые порты через `nmap`
Перед этим перезагружаемся, а затем устанавливаем:
   sudo apt install nmap
   И проверяем, какие порты открыты.

   nmap -sT localhost

Результат:
 Starting Nmap 7.93 ( https://nmap.org ) at 2025-09-09 17:25 MSK                 
 Nmap scan report for localhost (127.0.0.1)                                      
 Host is up (0.00085s latency).                                                  
 Other addresses for localhost (not scanned): ::1                                
 Not shown: 998 closed tcp ports (conn-refused)                                  
 PORT     STATE SERVICE                                                          
 111/tcp  open  rpcbind                                                          
 5432/tcp open  postgresql                                                       
                                                                                 
 Nmap done: 1 IP address (1 host up) scanned in 0.25 seconds                     
 admin@orangepi3b:~$




---

### Задание 3. Fail2ban (дополнительно)

Установить `fail2ban`.

```bash
sudo apt install fail2ban -y
```

Настроить блокировку IP после 3–5 неудачных попыток.
Проверить, что IP блокируется при многократном вводе неверного пароля.



---

### Задание 4. Логирование и анализ

Изучить файл логов:

```bash
sudo less /var/log/auth.log
```

Найти IP-адреса, с которых были попытки входа.
Подсчитать успешные и неуспешные подключения.
Составить краткий отчёт.
Я пошел немного другим путем, а именно- воспользовался анализатором логов awk. Он имеется в системе. Команда такая:
```bash
sudo awk '/Failed password|Invalid user|authentication failure|Accepted (password|publickey)/{ type=($0~/Failed|Invalid|authentication/? "FAIL":"OK"); ip=""; if(match($0,/from [[][0-9A-Fa-f.:]+[]]|from [0-9A-Fa-f.:]+/)){s=substr($0,RSTART,RLENGTH); sub(/^from /,"",s); gsub(/[\[\]]/,"",s); ip=s} else if(match($0,/rhost=[0-9A-Fa-f.:]+/)){s=substr($0,RSTART,RLENGTH); sub(/^rhost=/,"",s); ip=s} if(ip!=""){ failed[ip]+=(type=="FAIL"); ok[ip]+=(type=="OK"); seen[ip]=1 }} END{ print "IP,FAILED,OK"; for(i in seen) printf "%s,%d,%d\n", i, failed[i]+0, ok[i]+0 }' /var/log/auth.log* | sort -t, -k2 -nr | column -s, -t
```

По сути- это bash- скрипт.
через awk фильтруем только строки с попытками входа
Затем извлекаем IP. Учитываем как IP V4, так и IP V6, Иначе пробуем "rhost=<IP>".
По каждому найденному IP накапливаем counters failedи ok.
В блоке END выводим строки IP,FAILED,OK.
sort сортирует по полю FAILED по убыванию .
ну и column- форматирует CSV в таблицу для удобного чтения в терминале.
Результат:
 192.168.0.111  1       5                                                        
 IP             FAILED  OK                                                       
---



### Задание 5. Дополнительное

Настроить приветственное сообщение (`/etc/motd`).
Добавить ещё один разрешённый порт в iptables (например, 80 для будущего веб-сервера).
Подготовить список команд, которые вы использовали, и объяснить их назначение.




Добавим приветственное сообщение. Для этого нужно набрать в терминале:
```bash
   sudo nano /etc/motd
```
И вписать текст сообщения. Теперь при заходе на сервер вывод вот такой:
/ _ \| '_| '  \| '_ \ / _` | ' \  / _/ _ \ '  \| '  \ || | ' \| |  _| || |    
  /_/ \_\_| |_|_|_|_.__/_\__,_|_||_|_\__\___/_|_|_|_|_|_\_,_|_||_|_|\__|\_, |    
                                  |___|                                 |__/     
  v25.11 rolling for Orange Pi 3B running Armbian Linux 6.12.45-current-rockchip6
 4                                                                               
                                                                                 
  Packages:     Debian stable (bookworm), possible distro upgrade (trixie)       
  Support:      for advanced users (rolling release)                             
  IPv4:         (LAN) 192.168.0.109 (WAN) 85.143.145.158                         
                                                                                 
  Performance:                                                                   
                                                                                 
  Load:         26%               Uptime:       13 min                           
  Memory usage: 17% of 7.50G                                                     
  CPU temp:     43°C              Usage of /:   5% of 226G                       
  RX today:     535 MiB                                                          
  Commands:                                                                      
                                                                                 
  Configuration : armbian-config                                                 
  Monitoring    : htop                                                           
                                                                                 
 Velcome to debian experimental server! Have fun!                                
 Last login: Tue Sep  9 17:02:06 2025 from 192.168.0.111                         
 admin@orangepi3b:~$ 
Как видим, у нас появился текст приветственного сообщения.
Порт 80 был добавлен ранее.
