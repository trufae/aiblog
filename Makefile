all:
	$(MAKE) www-init
	sh gen.sh index
	sh gen.sh SplashScreen_Technique
	sh gen.sh android-malware-2025
	sh gen.sh SparkCat_Report
	sh gen.sh SpyNote_Report
	sh gen.sh Vultur_Report
	sh gen.sh ToxicPanda_Report
	sh gen.sh BadPack_Report
	sh gen.sh Joker_Report

www-init:
	rm -rf www
	mkdir -p www
	cp -f index.css www
