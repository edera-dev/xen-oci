.PHONY: all
all: libuc

LIBUC_VERSION ?= 1.5
LIBUC_SRC := $(abspath libucontext.git)
LIBUC_BRANCH ?= libucontext-$(LIBUC_VERSION)

$(LIBUC_SRC):
	git clone -b $(LIBUC_BRANCH) https://github.com/kaniini/libucontext.git $@

$(LIBUC_SRC)/libucontext.a: $(LIBUC_SRC)
	cd $(LIBUC_SRC) && make libucontext.a

.PHONY: libuc
libuc: $(LIBUC_SRC)/libucontext.a
