#/bin/bash
source /etc/profile
cd /home/bones/elite && git add -A && git commit -m "`echo -n 'auto commit ' ; date '+%Y-%m-%d %H:%M:%S'`" && git push origin main
