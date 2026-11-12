#!/bin/bash
# S6 (exynos7420) portunu J7 (exynos7580) iskeletine cevirir.
# Bu betik EDK2 agacinin KOKUNDE calisir:  EDK2_DIR=/yol/edk2-exynos bash 01_mkport.sh
set -e
R="${EDK2_DIR:-$(pwd)}"
cd "$R"
[ -d Platform/Samsung/exynos7420 ] || { echo "HATA: Platform/Samsung/exynos7420 yok; EDK2_DIR yanlis mi? ($R)" >&2; exit 1; }
P=Platform/Samsung; S=Silicon/Samsung
rm -rf $P/exynos7580 $S/Exynos7580Pkg
cp -r $P/exynos7420 $P/exynos7580
cp -r $S/Exynos7420Pkg $S/Exynos7580Pkg
rm -rf $P/exynos7580/FdtBlob_compat
cd $P/exynos7580
for f in exynos7420.*; do mv "$f" "${f/exynos7420/exynos7580}"; done
mv s6.dsc j7.dsc
cd "$R/$S/Exynos7580Pkg" && mv exynos7420.dec exynos7580.dec
cd "$R"
grep -rIl -E 'exynos7420|Exynos7420|EXYNOS7420' $P/exynos7580 $S/Exynos7580Pkg | while read f; do sed -i -e 's/exynos7420/exynos7580/g; s/Exynos7420/Exynos7580/g; s/EXYNOS7420/EXYNOS7580/g' "$f"; done
echo "files: $(find $P/exynos7580 $S/Exynos7580Pkg -type f | wc -l)"
echo "--- device specific constants left:"
grep -rnI -E '0x[0-9a-fA-F]{6,}|Galaxy|G920|\bs6\b|S6|7420' $P/exynos7580 $S/Exynos7580Pkg | grep -v '\.fdf' | head -70
