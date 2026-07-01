FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

SRC_URI += "file://imx6ull-alientek.dts"

do_configure:prepend() {
cp ${WORKDIR}/imx6ull-alientek.dts ${S}/arch/arm/boot/dts/
}
