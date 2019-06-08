EMACS ?= emacs

.PHONY: compile test

all: check

check: compile test

compile:
	${EMACS} -Q --batch -L . --eval "(setq byte-compile-error-on-warn t)" -f batch-byte-compile baidu-fanyi.el

test:
	${EMACS} -Q --batch -L . -l baidu-fanyi-test -f ert-run-tests-batch-and-exit


local:
	@for cmd in emacs-25.1 emacs-25.3 emacs-26.1 emacs-26.2; do \
	    command -v $$cmd && make EMACS=$$cmd ;\
	done
