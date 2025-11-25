# Отчёт

## по лабораторной работе № 3


Выполнил студент
Ковалев Никита, группа p4250  
Дата выполнения задания: 12.11.2025  
Наименование дисциплины: системное администрирование

## Лабораторная работа Nginx-прокси во внутренней сети с двумя бэкендами

## 1. Цель работы

Цель работы — развернуть во внутренней («серой») сети стенд из трёх узлов и настроить:

* Nginx как reverse-proxy на узле `proxy01`;
* два независимых HTTP-бэкенда на узлах `app01` и `app02` (порт `8080`);
* балансировку запросов с `proxy01` на оба бэкенда;
* логирование запросов в формате JSON с указанием upstream;
* простые health-checks и сценарий failover;
* сетевые ограничения (бэкенды доступны только с `proxy01`, наружу — только `proxy01:80`);
* reproducible-структуру репозитория с конфигами, юнитами, скриптами и результатами проверок.

## Структура папки
Финальная структура соответствует заданию:

```text
.
├── README.md
├── dns/
│   ├── zone.dc.local        # файл зоны или конфиг dnsmasq (при использовании DNS)
│   └── named.conf.local     # опциональный фрагмент bind9
├── proxy/
│   └── nginx.conf.d/
│       └── app.conf
├── app/
│   ├── app.py
│   └── systemd/
│       └── simple-backend@.service
├── firewall/
│   ├── app01.rules          # вывод/фиксация настроек fw для app01 (при наличии)
│   └── app02.rules          # вывод/фиксация настроек fw для app02 (при наличии)
└── checks/
    ├── dns.txt
    ├── backend.txt
    ├── proxy-roundrobin.txt
    ├── access-sample.json
    ├── failover.txt
    └── run_all.sh
```




## Топология и исходные данные
Во внутренней сети использованы три хоста:
| Хост    | Роль                    | DNS-имя          | IP-адрес   |
| ------- | ----------------------- | ---------------- | ---------- |
| proxy01 | reverse-proxy (Nginx)   | proxy01.dc.local | 10.100.0.1 |
| app01   | backend №1 (HTTP :8080) | app01.dc.local   | 10.100.0.2 |
| app02   | backend №2 (HTTP :8080) | app02.dc.local   | 10.100.0.3 |

### Настройка хостнеймов и /etc/hosts

На каждом узле:

```bash
sudo hostnamectl set-hostname app01
```

Для связи по именам использован статический `/etc/hosts`. На КАЖДОМ узле добавлены строки:

```text
10.100.0.1  proxy01.dc.local proxy01
10.100.0.2  app01.dc.local   app01
10.100.0.3  app02.dc.local   app02
```

Проверка:

```bash
host app01.dc.local
host app02.dc.local
host proxy01.dc.local
```

Результат этих команд сохранён в `checks/dns.txt`.


## Мини-бэкенды на app01 и app02
На узлах `app01` и `app02`:
```bash
sudo apt -y update && sudo apt -y install python3
sudo install -d -o root -g root /opt/simple-backend
```

Копирование необходимых файлов:
```bash
sudo cp app/app.py /opt/simple-backend/app.py
sudo cp app/systemd/simple-backend@.service \
  /etc/systemd/system/simple-backend@.service
sudo systemctl daemon-reload
```


На `app01`:

```bash
sudo systemctl enable --now simple-backend@app01
```

На `app02`:

```bash
sudo systemctl enable --now simple-backend@app02
```

Проверка статуса:

```bash
systemctl status simple-backend@app01
systemctl status simple-backend@app02
```

Проверка ответов с `proxy01`:

```bash
curl -s http://app01.dc.local:8080/
curl -s http://app02.dc.local:8080/
```

Эти два ответа сохранены в `checks/backend.txt`.


## Настройка Nginx как reverse-proxy
на proxy01
```bash
sudo apt -y update && sudo apt -y install nginx
sudo mkdir -p /etc/nginx/conf.d
```

```bash
sudo cp proxy/nginx.conf.d/app.conf /etc/nginx/conf.d/app.conf
```

По факту реализовано:

* upstream `app_backend` с двумя бэкендами `app01.dc.local:8080` и `app02.dc.local:8080`;
* round-robin балансировка (по умолчанию);
* `max_fails` и `fail_timeout` для простых health-check’ов;
* JSON-формат логов в `/var/log/nginx/access.json` с полями `ts`, `req_id`, `remote`, `upstream`, `status`, `rt`, `urt`, `ua`;
* проброс заголовков `X-Forwarded-For`, `X-Forwarded-Proto`, `X-Request-Id`;
* эндпоинт `/healthz` для проверки доступности прокси.

Проверка синтаксиса:

```bash
sudo nginx -t
```

Запуск и автозапуск:

```bash
sudo systemctl enable --now nginx
```

Проверка доступа через прокси:

```bash
curl -s http://proxy01.dc.local/
```

Для проверки балансировки:

```bash
for i in {1..10}; do
  curl -s http://proxy01.dc.local/
done
```

Вывод этих 10 запросов сохранён в `checks/proxy-roundrobin.txt` (ожидается присутствие ответов и от `app01`, и от `app02`).

---

## Сетевая безопасность

Задача: разрешить доступ к порту `8080` только с `proxy01` (10.100.0.1).

На каждом из бэкендов:

```bash
sudo apt -y install ufw

sudo ufw default deny incoming
sudo ufw default allow outgoing

# Разрешить 8080 только для proxy01
sudo ufw allow from 10.100.0.1 to any port 8080 proto tcp

sudo ufw enable
sudo ufw status verbose
```

И того 
* все входящие соединения запрещены;
* порт `8080` доступен только с IP `10.100.0.1`.

Задача: открыть наружу только HTTP (`80/tcp`).

На `proxy01`:

```bash
sudo apt -y install ufw

sudo ufw default deny incoming
sudo ufw default allow outgoing

sudo ufw allow 80/tcp

sudo ufw enable
sudo ufw status verbose
```

Теперь
* внешние клиенты могут обращаться только к `proxy01:80`;
* бэкенды полностью скрыты, работают только за прокси.

---


Для автоматизации формирования проверок использован скрипт `checks/run_all.sh`
После запуска скрипта в каталоге `checks/` находятся:

* `checks/dns.txt` — результат команд

  ```bash
  host app01.dc.local
  host app02.dc.local
  host proxy01.dc.local
  ```
* `checks/backend.txt` — результат:

  ```bash
  curl -s http://app01.dc.local:8080/
  curl -s http://app02.dc.local:8080/
  ```
* `checks/proxy-roundrobin.txt` — 10 запросов через прокси:

  ```bash
  for i in {1..10}; do curl -s http://proxy01.dc.local/; done
  ```
* `checks/access-sample.json` — первые 10 строк логов Nginx:

  ```bash
  sudo head -n 10 /var/log/nginx/access.json
  ```
* `checks/failover.txt` — проверка сценария отказа `app02` и восстановления:

  * остановка `simple-backend@app02`,
  * несколько запросов к `proxy01.dc.local`,
  * фрагмент логов во время отказа,
  * запуск `simple-backend@app02`,
  * несколько запросов после восстановления,
  * фрагмент логов после восстановления.




### Вывод
* развернуты три узла во внутренней сети с именами `proxy01.dc.local`, `app01.dc.local`, `app02.dc.local`;
* на `app01` и `app02` запущены HTTP-бэкенды по `app/app.py`, управляемые через `app/systemd/simple-backend@.service` как `simple-backend@app01` и `simple-backend@app02`;
* на `proxy01` установлен и настроен Nginx с конфигом `proxy/nginx.conf.d/app.conf`, реализующим reverse-proxy, round-robin балансировку и JSON-логи с информацией об upstream;
* с помощью ufw настроены сетевые ограничения: бэкенды доступны по порту `8080` только с `proxy01`, наружу открыт только `proxy01:80`;
* с помощью скрипта `checks/run_all.sh` сформированы текстовые доказательства работоспособности: DNS, доступность бэкендов, балансировка, корректность логов и сценарий failover.

Все требования задания «Nginx-прокси во внутренней сети с двумя бэкендами» выполнены.
