MDS=$(shell cd src ; ls | grep md$ |sed -e 's,.md,,')

all:
	$(MAKE) www-init
	for a in $(MDS); do sh gen.sh $$a ; done

www-init:
	rm -rf www
	mkdir -p www
	cp -f index.css www
	cp -rf src/img www/img
