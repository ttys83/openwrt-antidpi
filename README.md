# SNR-CPE-AX2: OpenWrt 25.12.5 с zapret2, DoH и Passwall2

Проект собирает образ `sysupgrade` для `snr,snr-cpe-ax2` (`mediatek/filogic`, `aarch64_cortex-a53`). За основу взята официальная OpenWrt 25.12.5, совпадающая с версией на роутере. В образ включены:

- `zapret2` и `luci-app-zapret2` версии 1.0.5.2-r1 из репозитория Routerich;
- конфигурация zapret2, скрипт Discord Media и списки из Zapret-Manager;
- `https-dns-proxy` и `luci-app-https-dns-proxy` из репозитория OpenWrt;
- профиль DoH Cloudflare + Google, выбранный пользователем, с настройками из Zapret-Manager;
- `luci-app-passwall2` 26.9.16-r1 с `xray-core` 26.9.9-r1, без `sing-box`;
- `dnsmasq-full` с nftset вместо обычного `dnsmasq`, а также модули nftables и nf для прозрачного прокси Passwall2;
- LuCI;
- собственный BusyBox с обработкой UTF-8 в `ash` и поиском истории по префиксу через ↑/↓.
- SSH-ключ компьютера, отдельный Dropbear на WAN (`21022/tcp`, только ключ) и цветное приглашение `ash`.

Сам Zapret-Manager и его остальные приложения в образ не включены.

Для WAN по DHCP или со статическим IPv4-адресом из образа исключены PPP/PPPoE и пользовательские пакеты IPv6. LuCI собирается из нужных компонентов без метапакетов `luci` и `luci-light`, которые устанавливают страницы настройки этих протоколов; веб-интерфейс управления пакетами сохранён. DoH использует только IPv4. Новый образ `sysupgrade` занимает 28 565 774 байта. Модули IPv6, требуемые firewall и Passwall2, остаются в образе.

Passwall2 установлен, но по умолчанию выключен. При первом запуске его пакет создаёт `/etc/config/passwall2` из шаблона с `option enabled '0'`. Добавьте свой узел Xray и настройте правила перед включением сервиса. `https-dns-proxy` остаётся включённым и продолжает обслуживать существующий профиль DoH. Если включить в Passwall2 перехват DNS, проверьте настройки `dnsmasq` и фактический маршрут запросов: оба сервиса могут менять DNS-цепочку. Сборка образа не проверяет работу прокси и DNS на самом роутере.

## Сборка

На macOS с работающим Docker Desktop:

```sh
sh scripts/build-image.sh
```

Сценарий скачивает официальные Image Builder и SDK, проверяет SHA-256, собирает BusyBox 1.37.0-r7 с патчем истории, затем создаёт файл `output/*zapret2-doh-passwall2*snr_snr-cpe-ax2*squashfs-sysupgrade.itb`. После сборки он извлекает файловую систему образа и проверяет BusyBox, пакеты, конфигурацию, поддержку nftset в `dnsmasq-full` и файлы модулей ядра. Перед прошивкой проверьте, что созданный файл соответствует этому устройству. Рабочий каталог `build/` и результаты `output/` не включаются в исходные файлы проекта.

В интерактивном `ash` наберите начало команды и нажимайте ↑/↓: история будет показывать команды с этим префиксом, учитывая регистр. Пустая строка сохраняет обычную навигацию по истории. После редактирования строки следующий поиск начнётся заново. Поведение клавиш и ввод кириллицы нужно проверить на роутере после прошивки.

При первом запуске образ добавляет открытый ключ `~/.ssh/id_rsa.pub` этого компьютера в `/etc/dropbear/authorized_keys`, привязывает обычный SSH к LAN и включает второй экземпляр Dropbear на WAN с портом `21022`. Для WAN отключена авторизация по паролю; firewall разрешает входящий TCP/21022 по IPv4. Настройка первого запуска также применяется после `sysupgrade` с сохранением конфигурации и не удаляет другие разрешённые SSH-ключи. Подключение: `ssh -p 21022 root@<WAN-IP-роутера>`. Приглашение имеет вид `[root@hostname] /usr/bin #`; цвет включается в интерактивном терминале, кроме `TERM=dumb`.

Локальная проверка редактора командной строки в псевдотерминале:

```sh
docker run --rm --platform linux/amd64 -v "$PWD:/project:ro" openwrt-custom-imagebuilder:25.12.5 sh /project/scripts/test-busybox-lineedit-in-container.sh
```

## Источники

- [Официальный Image Builder и образ OpenWrt 25.12.5](https://downloads.openwrt.org/releases/25.12.5/targets/mediatek/filogic/). SHA-256 Image Builder: `7fb6cf626582ebcbfb46974da48c1eae577213f38879eaf6b1d982041e843461`.
- Пакеты [zapret2](https://packages.routerich.ru/25.12/mediatek/filogic/routerich/zapret2-1.0.5.2-r1.apk) и [luci-app-zapret2](https://packages.routerich.ru/25.12/mediatek/filogic/routerich/luci-app-zapret2-1.0.5.2-r1.apk), сохранены в `vendor/routerich/` с проверкой SHA-256 в сценарии сборки.
- Пакеты [Passwall2](https://github.com/Openwrt-Passwall/openwrt-passwall2/releases) и [репозитория Passwall](https://sourceforge.net/projects/openwrt-passwall-build/files/releases/packages-25.12/aarch64_cortex-a53/), сохранены в `vendor/passwall2/` с проверкой SHA-256 в сценарии сборки. Модули ядра и `dnsmasq-full` устанавливаются из официального репозитория OpenWrt 25.12.5.
- [Zapret-Manager, коммит `ace5a865d86a02ed7225dbcc4f73c06475b8d807`](https://github.com/StressOzz/Zapret-Manager/tree/ace5a865d86a02ed7225dbcc4f73c06475b8d807). Взяты только файлы, которые функция `install_zapret2` скачивает после установки пакетов, и настройки DoH Cloudflare + Google.

Обновление Zapret-Manager или сохранённых пакетов Routerich и Passwall2 не меняет уже собранный образ автоматически. Для обновления нужно осознанно заменить файлы и контрольные суммы, затем собрать образ заново.

## Перед прошивкой

Сначала сохраните резервную копию конфигурации роутера командой `sysupgrade -b /tmp/openwrt-backup.tar.gz` и скопируйте архив с роутера на компьютер. Образ пока не прошивается этим проектом. При обновлении с сохранением настроек существующие файлы `/etc/config/zapret2`, `/etc/config/https-dns-proxy` и `/etc/config/passwall2` могут перекрыть настройки, включённые в образ; это нужно проверить перед обновлением. После прошивки проверьте запуск `dnsmasq-full`, работу DoH, LuCI и Passwall2 с вашим узлом Xray.
