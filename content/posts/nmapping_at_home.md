---
Title: "Nmaping home network"
Date: "2017-02-27"
Category: hacking
draft: true
Tags: [networks]
Author: Petr Tikilyaynen
description: "What can nmap tell us about our flatmates?"
---

```bash
petr_tik@merluza:~$ nmap -PR 192.168.0.1/24 -sn

Starting Nmap 6.47 ( http://nmap.org ) at 2017-09-15 23:32 BST
Nmap done: 256 IP addresses (0 hosts up) scanned in 0.00 seconds
petr_tik@merluza:~$ nmap -sP 192.168.0.1/24 -sn

Starting Nmap 6.47 ( http://nmap.org ) at 2017-09-15 23:32 BST
Nmap scan report for 192.168.0.1
Host is up (0.021s latency).
Nmap scan report for 192.168.0.3
Host is up (0.034s latency).
Nmap scan report for 192.168.0.30
Host is up (0.000043s latency).
Nmap scan report for 192.168.0.31
Host is up (0.0059s latency).
Nmap done: 256 IP addresses (4 hosts up) scanned in 2.45 seconds
petr_tik@merluza:~$ sudo nmap -O -v 192.168.0.1
sudo nmap -O -v 192.168.0.1

Starting Nmap 6.47 ( http://nmap.org ) at 2017-09-15 23:33 BST
Initiating ARP Ping Scan at 23:33
Scanning 192.168.0.1 [1 port]
Completed ARP Ping Scan at 23:33, 0.21s elapsed (1 total hosts)
Initiating Parallel DNS resolution of 1 host. at 23:33
Completed Parallel DNS resolution of 1 host. at 23:33, 0.01s elapsed
Initiating SYN Stealth Scan at 23:33
Scanning 192.168.0.1 [1000 ports]
Discovered open port 80/tcp on 192.168.0.1
Discovered open port 5000/tcp on 192.168.0.1
Discovered open port 1900/tcp on 192.168.0.1
Completed SYN Stealth Scan at 23:34, 19.15s elapsed (1000 total ports)
Initiating OS detection (try #1) against 192.168.0.1
Nmap scan report for 192.168.0.1
Host is up (0.019s latency).
Not shown: 994 filtered ports
PORT     STATE  SERVICE
23/tcp   closed telnet
80/tcp   open   http
443/tcp  closed https
1900/tcp open   upnp
5000/tcp open   upnp
8080/tcp closed http-proxy
MAC Address: 2C:B0:5D:17:EF:1F (Netgear)
Device type: broadband router
Running: Cisco eCos 2.X, Motorola eCos 2.X, Scientific Atlanta eCos 2.X
OS CPE: cpe:/h:cisco:epc3925 cpe:/h:motorola:sb5101e cpe:/h:scientific_atlanta:epc2203
OS details: Cisco EPC3925, DPC2320, Motorola SURFboard SB5101E, or Scientific Atlanta EPC2203 cable modem (eCos 2.0)
Uptime guess: 17.035 days (since Tue Aug 29 22:44:26 2017)
Network Distance: 1 hop
TCP Sequence Prediction: Difficulty=258 (Good luck!)
IP ID Sequence Generation: Incremental

Read data files from: /usr/bin/../share/nmap
OS detection performed. Please report any incorrect results at http://nmap.org/submit/ .
Nmap done: 1 IP address (1 host up) scanned in 21.75 seconds
           Raw packets sent: 3049 (136.378KB) | Rcvd: 72 (3.890KB)
petr_tik@merluza:~$ sudo nmap -O -v 192.168.0.3

Starting Nmap 6.47 ( http://nmap.org ) at 2017-09-15 23:34 BST
Initiating ARP Ping Scan at 23:34
Scanning 192.168.0.3 [1 port]
Completed ARP Ping Scan at 23:34, 0.21s elapsed (1 total hosts)
Initiating Parallel DNS resolution of 1 host. at 23:34
Completed Parallel DNS resolution of 1 host. at 23:34, 0.01s elapsed
Initiating SYN Stealth Scan at 23:34
Scanning 192.168.0.3 [1000 ports]
Increasing send delay for 192.168.0.3 from 0 to 5 due to 22 out of 72 dropped probes since last increase.
Discovered open port 7100/tcp on 192.168.0.3
Increasing send delay for 192.168.0.3 from 5 to 10 due to 14 out of 45 dropped probes since last increase.
Increasing send delay for 192.168.0.3 from 10 to 20 due to max_successful_tryno increase to 4
Increasing send delay for 192.168.0.3 from 20 to 40 due to 15 out of 48 dropped probes since last increase.
Increasing send delay for 192.168.0.3 from 40 to 80 due to 11 out of 26 dropped probes since last increase.
Increasing send delay for 192.168.0.3 from 80 to 160 due to max_successful_tryno increase to 5
Increasing send delay for 192.168.0.3 from 160 to 320 due to max_successful_tryno increase to 6
SYN Stealth Scan Timing: About 41.85% done; ETC: 23:35 (0:00:43 remaining)
SYN Stealth Scan Timing: About 51.16% done; ETC: 23:36 (0:00:58 remaining)
Discovered open port 62078/tcp on 192.168.0.3
Discovered open port 3689/tcp on 192.168.0.3
Discovered open port 7000/tcp on 192.168.0.3
SYN Stealth Scan Timing: About 69.95% done; ETC: 23:37 (0:00:52 remaining)
SYN Stealth Scan Timing: About 81.16% done; ETC: 23:37 (0:00:36 remaining)
Discovered open port 5000/tcp on 192.168.0.3
Discovered open port 49155/tcp on 192.168.0.3
Completed SYN Stealth Scan at 23:39, 268.62s elapsed (1000 total ports)
Initiating OS detection (try #1) against 192.168.0.3
Nmap scan report for 192.168.0.3
Host is up (0.024s latency).
Not shown: 994 closed ports
PORT      STATE SERVICE
3689/tcp  open  rendezvous
5000/tcp  open  upnp
7000/tcp  open  afs3-fileserver
7100/tcp  open  font-service
49155/tcp open  unknown
62078/tcp open  iphone-sync
MAC Address: C8:69:CD:63:80:70 (Unknown)
Device type: general purpose|media device|phone
Running: Apple Mac OS X 10.7.X|10.9.X|10.8.X, Apple iOS 4.X|5.X|6.X
OS CPE: cpe:/o:apple:mac_os_x:10.7 cpe:/o:apple:mac_os_x:10.9 cpe:/o:apple:mac_os_x:10.8 cpe:/o:apple:iphone_os:4 cpe:/a:apple:apple_tv:4 cpe:/o:apple:iphone_os:5 cpe:/o:apple:iphone_os:6
OS details: Apple Mac OS X 10.7.0 (Lion) - 10.9.2 (Mavericks) or iOS 4.1 - 7.1 (Darwin 10.0.0 - 14.0.0)
Uptime guess: 13.415 days (since Sat Sep  2 13:41:17 2017)
Network Distance: 1 hop
TCP Sequence Prediction: Difficulty=254 (Good luck!)
IP ID Sequence Generation: Randomized

Read data files from: /usr/bin/../share/nmap
OS detection performed. Please report any incorrect results at http://nmap.org/submit/ .
Nmap done: 1 IP address (1 host up) scanned in 270.89 seconds
           Raw packets sent: 2318 (103.194KB) | Rcvd: 1060 (43.226KB)
petr_tik@merluza:~$ sudo nmap -O 192.168.0.60

Starting Nmap 6.47 ( http://nmap.org ) at 2017-09-15 23:40 BST
Nmap scan report for 192.168.0.60
Host is up (0.017s latency).
Not shown: 987 closed ports
PORT      STATE    SERVICE
808/tcp   filtered ccproxy-http
1049/tcp  filtered td-postman
1080/tcp  filtered socks
1092/tcp  filtered obrpd
1218/tcp  filtered aeroflight-ads
3007/tcp  filtered lotusmtap
3390/tcp  filtered dsc
6510/tcp  filtered mcer-port
6547/tcp  filtered powerchuteplus
7676/tcp  filtered imqbrokerd
45100/tcp filtered unknown
49175/tcp filtered unknown
62078/tcp open     iphone-sync
MAC Address: E0:5F:45:51:9A:20 (Unknown)
Device type: general purpose|media device|phone
Running: Apple Mac OS X 10.7.X|10.9.X|10.8.X, Apple iOS 4.X|5.X|6.X
OS CPE: cpe:/o:apple:mac_os_x:10.7 cpe:/o:apple:mac_os_x:10.9 cpe:/o:apple:mac_os_x:10.8 cpe:/o:apple:iphone_os:4 cpe:/a:apple:apple_tv:4 cpe:/o:apple:iphone_os:5 cpe:/o:apple:iphone_os:6
OS details: Apple Mac OS X 10.7.0 (Lion) - 10.9.2 (Mavericks) or iOS 4.1 - 7.1 (Darwin 10.0.0 - 14.0.0)
Network Distance: 1 hop

OS detection performed. Please report any incorrect results at http://nmap.org/submit/ .
Nmap done: 1 IP address (1 host up) scanned in 281.18 seconds
petr_tik@merluza:~$ sudo nmap -v -O 192.168.0.30

Starting Nmap 6.47 ( http://nmap.org ) at 2017-09-15 23:46 BST
Initiating Parallel DNS resolution of 1 host. at 23:46
Completed Parallel DNS resolution of 1 host. at 23:46, 0.01s elapsed
Initiating SYN Stealth Scan at 23:46
Scanning 192.168.0.30 [1000 ports]
Discovered open port 5432/tcp on 192.168.0.30
Completed SYN Stealth Scan at 23:46, 1.56s elapsed (1000 total ports)
Initiating OS detection (try #1) against 192.168.0.30
Nmap scan report for 192.168.0.30
Host is up (0.000020s latency).
Not shown: 999 closed ports
PORT     STATE SERVICE
5432/tcp open  postgresql
Device type: general purpose
Running: Linux 3.X
OS CPE: cpe:/o:linux:linux_kernel:3
OS details: Linux 3.7 - 3.15
Uptime guess: 2.520 days (since Wed Sep 13 11:18:26 2017)
Network Distance: 0 hops
TCP Sequence Prediction: Difficulty=255 (Good luck!)
IP ID Sequence Generation: All zeros

Read data files from: /usr/bin/../share/nmap
OS detection performed. Please report any incorrect results at http://nmap.org/submit/ .
Nmap done: 1 IP address (1 host up) scanned in 4.07 seconds
           Raw packets sent: 1112 (50.780KB) | Rcvd: 2234 (96.984KB)
petr_tik@merluza:~$ sudo nmap -v -O 192.168.0.31

Starting Nmap 6.47 ( http://nmap.org ) at 2017-09-15 23:47 BST
Initiating ARP Ping Scan at 23:47
Scanning 192.168.0.31 [1 port]
Completed ARP Ping Scan at 23:47, 0.20s elapsed (1 total hosts)
Initiating Parallel DNS resolution of 1 host. at 23:47
Completed Parallel DNS resolution of 1 host. at 23:47, 0.01s elapsed
Initiating SYN Stealth Scan at 23:47
Scanning 192.168.0.31 [1000 ports]
Increasing send delay for 192.168.0.31 from 0 to 5 due to 22 out of 72 dropped probes since last increase.
Increasing send delay for 192.168.0.31 from 5 to 10 due to 13 out of 41 dropped probes since last increase.
Increasing send delay for 192.168.0.31 from 10 to 20 due to max_successful_tryno increase to 4
Increasing send delay for 192.168.0.31 from 20 to 40 due to 11 out of 31 dropped probes since last increase.
Increasing send delay for 192.168.0.31 from 40 to 80 due to max_successful_tryno increase to 5
Discovered open port 62078/tcp on 192.168.0.31
Completed SYN Stealth Scan at 23:48, 95.42s elapsed (1000 total ports)
Initiating OS detection (try #1) against 192.168.0.31
Nmap scan report for 192.168.0.31
Host is up (0.0045s latency).
Not shown: 999 closed ports
PORT      STATE SERVICE
62078/tcp open  iphone-sync
MAC Address: E4:9A:79:EA:06:A4 (Unknown)
Device type: general purpose|media device|phone
Running: Apple Mac OS X 10.7.X|10.9.X|10.8.X, Apple iOS 4.X|5.X|6.X
OS CPE: cpe:/o:apple:mac_os_x:10.7 cpe:/o:apple:mac_os_x:10.9 cpe:/o:apple:mac_os_x:10.8 cpe:/o:apple:iphone_os:4 cpe:/a:apple:apple_tv:4 cpe:/o:apple:iphone_os:5 cpe:/o:apple:iphone_os:6
OS details: Apple Mac OS X 10.7.0 (Lion) - 10.9.2 (Mavericks) or iOS 4.1 - 7.1 (Darwin 10.0.0 - 14.0.0)
Uptime guess: 2.064 days (since Wed Sep 13 22:16:26 2017)
Network Distance: 1 hop
TCP Sequence Prediction: Difficulty=257 (Good luck!)
IP ID Sequence Generation: Randomized

Read data files from: /usr/bin/../share/nmap
OS detection performed. Please report any incorrect results at http://nmap.org/submit/ .
Nmap done: 1 IP address (1 host up) scanned in 97.79 seconds
           Raw packets sent: 2357 (105.006KB) | Rcvd: 1297 (52.606KB)
```
