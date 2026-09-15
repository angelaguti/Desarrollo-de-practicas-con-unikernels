.PHONY: module clean

CFLAGS = -O2 -Wall -Wextra -Wpedantic \
         -std=gnu11 -fpie -rdynamic \
         -U_FORTIFY_SOURCE -D_FORTIFY_SOURCE=0

module: servidor-http-tfg

servidor-http-tfg: servidor_http_tfg.c
	$(CC) -pie -o $@ $(CFLAGS) $(LDFLAGS) $<

clean:
	rm -f servidor-http-tfg
