BIN := hanuman
VERSION := 0.1.0
OUT := zig-out/bin
OPTIMIZE := ReleaseFast

.PHONY: release clean \
	linux-x86_64 linux-aarch64 \
	macos-x86_64 macos-aarch64 \
	windows-x86_64 windows-aarch64 \
	build-local

hanuman:
	zig build --release=fast
	mv zig-out/bin/hanuman ./

release: linux-x86_64 linux-aarch64 macos-x86_64 macos-aarch64 windows-x86_64 windows-aarch64

# $(1) = label, $(2) = zig target triple, $(3) = binary suffix (e.g. .exe)
define build_target
	@echo ">> building $(1) ($(2)) v$(VERSION)"
	@mkdir -p $(OUT)
	zig build -Doptimize=$(OPTIMIZE) -Dtarget=$(2)
	mv $(OUT)/$(BIN)$(3) $(OUT)/$(BIN)-$(VERSION)-$(1)$(3)
endef

linux-x86_64:
	$(call build_target,linux-x86_64,x86_64-linux,)

linux-aarch64:
	$(call build_target,linux-aarch64,aarch64-linux,)

macos-x86_64:
	$(call build_target,macos-x86_64,x86_64-macos,)

macos-aarch64:
	$(call build_target,macos-aarch64,aarch64-macos,)

windows-x86_64:
	$(call build_target,windows-x86_64,x86_64-windows,.exe)

windows-aarch64:
	$(call build_target,windows-aarch64,aarch64-windows,.exe)

clean:
	rm -rf zig-out .zig-cache zig-cache ./hanuman

