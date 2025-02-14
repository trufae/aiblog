all:
	sh gen.sh index
	sh gen.sh android-malware-2025
	sh gen.sh SparkCat_Report
	sh gen.sh SpyNote_Report
	sh gen.sh Vultur_Report
	sh gen.sh ToxicPanda_Report
	sh gen.sh BadPack_Report
	sh gen.sh Joker_Report
