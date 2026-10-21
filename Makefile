.PHONY: help hw02-setup hw02-check

help:
	@echo 'make hw02-setup  Install HW02 dependencies and run all checks'
	@echo 'make hw02-check  Run HW02 checks with installed dependencies'

hw02-setup:
	bash homeworks/hw02-tripfund/scripts/setup.sh

hw02-check:
	bash homeworks/hw02-tripfund/scripts/check.sh
