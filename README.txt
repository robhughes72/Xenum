./Xenum.sh 50 500 1-65535 (full port scan) eth0

THen select option 1 for just a full TCP port scan (using masscan to find open ports, then nmap to perform a service scan with default safe scripts) or option 2 to include a default (fast top 100) UDP scan. 