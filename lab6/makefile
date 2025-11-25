
all: alltasks

alltasks: task1 task2 task3 task4 task5 task6 task7 task8

prep:
	@chmod +x tasks/*/*.sh tasks/*/*.py 2>/dev/null || true

task1: prep
	strace -tt -T -y -e trace=file,desc -o logs/01.strace ./tasks/01-permissions/broken.sh || true

task2: prep
	strace -tt -T -y -s 120 -e trace=file,desc -o logs/02.strace ./tasks/02-missing-file/broken.sh || true

task3: prep
	strace -f -tt -T -yy -s 200 -e trace=network,desc,signal \
		-o logs/03.strace python3 tasks/03-dns-timeout/client.py || true

task4: prep
	strace -tt -T -yy -e trace=network,connect,desc \
		-o logs/04.strace ./tasks/04-port-denied/tcp.sh || true

task5: prep
	@echo "=== Запускаем lock.py и ловим блокировку ==="
	python3 tasks/05-file-lock/lock.py >/dev/null 2>&1 & \
	LOCK_PID=$$!; \
	sleep 2; \
	strace -p $$LOCK_PID -tt -T -f -y -s 200 -e trace=flock,fcntl,futex,write,desc \
		-o logs/05.strace 2>/dev/null || true; \
	kill -TERM $$LOCK_PID 2>/dev/null || true; \
	wait $$LOCK_PID 2>/dev/null || true

task6: prep
	strace -tt -T -y -e trace=write,fsync,fdatasync,close,desc \
		-o logs/06.strace python3 tasks/06-slow-fsync/slow_write.py || true

task7: prep
	strace -ff -tt -T -y -s 120 -e trace=trace=process,file,desc \
		-o logs/07 bash tasks/07-daemonize/daemon.sh || true

task8: prep
	@echo "=== Загружаем тестовый AppArmor-профиль ==="
	@AA_PROFILE=$$(mktemp -d); \
	cp tasks/08-apparmor/profile "$$AA_PROFILE/profile"; \
	sudo /sbin/apparmor_parser -r -W -T "$$AA_PROFILE/profile" || echo "AppArmor не активен — будет EACCES от прав файла (тоже ок)"; \
	strace -tt -T -y -e trace=file,desc \
		-o logs/08.strace python3 -c "open('/etc/shadow').read()" || true; \
	sudo aa-remove-unknown 2>/dev/null || true; \
	rm -rf "$$AA_PROFILE"

# Удобно: чистим логи перед новым запуском
clean:
	rm -f logs/*.strace

.PHONY: all alltasks prep task1 task2 task3 task4 task5 task6 task7 task8 clean